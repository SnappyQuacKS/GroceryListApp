import SwiftUI
import Observation
import CryptoKit

// MARK: - AppStore (faithful Swift port of the Python grocery_model.py)
// Storage mirrors the PostgreSQL schema: items, grocery_lists, list_entries, users tables.
// Each mutation saves to UserDefaults (local cache) and pushes to the FastAPI/PostgreSQL
// server in the background. On startup the server state replaces the local cache.

@Observable
class AppStore {

    // In-memory store (identical structure to PostgreSQL tables)
    var lists:   [String: GroceryList] = [:]
    var items:   [String: Item]        = [:]
    var entries: [ListEntry]           = []
    var users:   [String: AppUser]     = [:]

    // Auth
    var currentUser: AppUser? = nil
    var isAuthenticated = false
    var isGuest = false

    // Server sync — set serverURL to enable PostgreSQL backend
    var serverURL: String = "" {
        didSet {
            UserDefaults.standard.set(serverURL, forKey: serverURLKey)
            if !serverURL.isEmpty { Task { await syncFromServer() } }
        }
    }
    var serverStatus: ServerSyncStatus = .notConfigured

    enum ServerSyncStatus: Equatable {
        case notConfigured, syncing, ok, error(String)
    }

    var serverStatusText: String {
        switch serverStatus {
        case .ok:              return "Connected to database"
        case .syncing:         return "Connecting…"
        case .error(let msg):  return msg
        case .notConfigured:   return "No server configured"
        }
    }

    private var network: NetworkService? {
        serverURL.isEmpty ? nil : NetworkService(baseURL: serverURL)
    }

    private let storageKey      = "grocery_db_v3"
    private let serverURLKey    = "server_url_v1"
    private let defaultServerURL = "http://192.168.0.128:8000"

    init() {
        let saved = UserDefaults.standard.string(forKey: "server_url_v1") ?? ""
        serverURL = saved.isEmpty ? defaultServerURL : saved
        if saved.isEmpty {
            UserDefaults.standard.set(serverURL, forKey: "server_url_v1")
        }
        loadData()
        Task { await checkServerHealth() }
    }

    // ── Auth ──────────────────────────────────────────────────────────────────

    func continueAsGuest() {
        lists = [:]
        items = [:]
        entries = []
        users = [:]
        currentUser = nil
        isGuest = true
        isAuthenticated = true
    }

    func signInWithApple(userIdentifier: String, email: String?, fullName: PersonNameComponents?) {
        let username = email ?? "apple_\(userIdentifier)"
        let firstName = fullName?.givenName ?? ""
        let lastName  = fullName?.familyName ?? ""

        // Reuse existing account or create new one
        let user = users[username] ?? AppUser(
            username: username,
            passwordHash: "apple_\(userIdentifier)",
            firstName: firstName,
            lastName: lastName
        )
        users[username] = user
        currentUser = user
        isGuest = false
        isAuthenticated = true
        saveData()
        Task { await syncFromServer() }
    }

    /// Sign in — validates credentials against server. Returns nil on success, error string on failure.
    func signIn(email: String, password: String) async -> String? {
        let hash = _sha256(password)
        guard let net = network else {
            return "No server connection."
        }
        guard let serverUser = try? await net.signIn(username: email, passwordHash: hash) else {
            return "Invalid email or password."
        }
        users[serverUser.username] = serverUser
        currentUser = serverUser
        isGuest = false
        isAuthenticated = true
        await syncFromServer()
        return nil
    }

    /// Create a new account on the server.
    func createAccount(email: String, password: String) async -> String? {
        let hash = _sha256(password)
        guard let net = network else {
            return "No server connection."
        }
        guard let newUser = try? await net.signUp(username: email, passwordHash: hash) else {
            return "An account with that email already exists."
        }
        users[newUser.username] = newUser
        currentUser = newUser
        isGuest = false
        isAuthenticated = true
        saveData()
        return nil
    }

    func signOut() {
        // Clear local data so next user starts fresh
        lists = [:]; items = [:]; entries = []; users = [:]
        UserDefaults.standard.removeObject(forKey: storageKey)
        currentUser = nil
        isAuthenticated = false
        isGuest = false
    }

    func updateCurrentUser(firstName: String, lastName: String, zipCode: String = "") {
        guard var u = currentUser else { return }
        u.firstName = firstName
        u.lastName  = lastName
        u.zipCode   = zipCode
        currentUser = u
        users[u.username] = u
        saveData()
    }

    // ── List operations (ListManager) ─────────────────────────────────────────

    /// All lists topologically sorted (parents before children).
    var sortedLists: [GroceryList] {
        _topoSort(Array(lists.values))
    }

    func createList(name: String, parentId: String? = nil, theme: ListTheme = .natural) {
        if let pid = parentId, lists[pid] == nil { return }
        let listName = name.isEmpty ? _autoName() : name
        let list = GroceryList(listName: listName, parentId: parentId,
                               userId: currentUser?.username, theme: theme)
        lists[list.listId] = list
        saveData()
    }

    func renameList(_ listId: String, to newName: String) {
        guard !newName.isEmpty else { return }
        lists[listId]?.listName = newName
        saveData()
    }

    func updateTheme(_ theme: ListTheme, for listId: String) {
        lists[listId]?.theme = theme
        saveData()
    }

    /// Safely removes a list. Children are re-parented to the grandparent and
    /// any items they were inheriting from the deleted list are hard-copied so
    /// the child's visible contents do not change.
    func deleteList(_ listId: String) {
        guard let target = lists[listId] else { return }
        let grandparentId = target.parentId
        let children = lists.values.filter { $0.parentId == listId }

        // Snapshot each child's current visible view
        let snapshots: [String: [DisplayItem]] = Dictionary(uniqueKeysWithValues:
            children.map { ($0.listId, compileDisplayItems(listId: $0.listId)) }
        )

        // Re-parent children to grandparent
        for child in children { lists[child.listId]?.parentId = grandparentId }

        // Remove the deleted list and its entries
        entries.removeAll { $0.listId == listId }
        lists.removeValue(forKey: listId)

        // Repair: hard-copy any items that disappeared from children
        for child in children {
            guard let before = snapshots[child.listId] else { continue }
            let afterIds = Set(compileDisplayItems(listId: child.listId).map { $0.itemId })

            for snap in before where !afterIds.contains(snap.itemId) {
                let master = items[snap.itemId]
                let override: String? = (master == nil || master!.itemName != snap.name) ? snap.name : nil
                entries.removeAll { $0.listId == child.listId && $0.itemId == snap.itemId }
                entries.append(ListEntry(listId: child.listId, itemId: snap.itemId,
                                         isChecked: snap.isChecked, customNameOverride: override))
            }
        }
        saveData()
    }

    /// Flattens the full compiled view of a list into a standalone copy with no
    /// inheritance links — matches Python's duplicateAsDecoupledCopy.
    @discardableResult
    func duplicateAsDecoupledCopy(listId: String) -> GroceryList? {
        guard let source = lists[listId] else { return nil }
        let snapshot = compileDisplayItems(listId: listId)
        let copy = GroceryList(listName: "Copy of \(source.listName)",
                               parentId: nil, userId: source.userId, theme: source.theme)
        lists[copy.listId] = copy

        for snap in snapshot {
            let master = items[snap.itemId]
            let override: String? = (master == nil || master!.itemName != snap.name) ? snap.name : nil
            entries.append(ListEntry(listId: copy.listId, itemId: snap.itemId,
                                     isChecked: snap.isChecked, customNameOverride: override))
        }
        saveData()
        return copy
    }

    func parentList(for list: GroceryList) -> GroceryList? {
        guard let pid = list.parentId else { return nil }
        return lists[pid]
    }

    // ── Item display (bottom-up compilation) ─────────────────────────────────

    /// Returns the resolved, visible item list for a given list.
    /// Direct items appear first (insertion order), inherited items follow.
    /// Masked-hidden items are excluded.
    /// Matches Python's readListDisplayItems / _compileDisplayMap.
    func compileDisplayItems(listId: String) -> [DisplayItem] {
        var result: [DisplayItem] = []
        var seenIds: Set<String>  = []
        var hiddenIds: Set<String> = []
        var ancestorItemIds: Set<String> = []
        var pointer: String? = listId
        var visited: Set<String> = []

        while let current = pointer, !visited.contains(current) {
            visited.insert(current)
            let isAncestor = current != listId

            for entry in entries where entry.listId == current {
                if isAncestor { ancestorItemIds.insert(entry.itemId) }
                if seenIds.contains(entry.itemId) || hiddenIds.contains(entry.itemId) { continue }

                if entry.isMaskedHidden {
                    hiddenIds.insert(entry.itemId)
                    continue
                }

                seenIds.insert(entry.itemId)
                let master = items[entry.itemId]
                let name = entry.customNameOverride ?? master?.itemName ?? "Unknown"
                result.append(DisplayItem(itemId: entry.itemId, name: name,
                                          isChecked: entry.isChecked, isInherited: isAncestor))
            }
            pointer = lists[current]?.parentId
        }

        // Mark forked items (local entry overriding an ancestor) as inherited
        return result.map { item in
            guard ancestorItemIds.contains(item.itemId) else { return item }
            return DisplayItem(itemId: item.itemId, name: item.name,
                               isChecked: item.isChecked, isInherited: true)
        }
    }

    // ── Item operations (ItemManager) ────────────────────────────────────────

    func addItem(to listId: String, name: String) {
        guard !name.isEmpty, lists[listId] != nil else { return }

        // Reuse existing master item if same name
        let itemId = items.values.first(where: { $0.itemName == name })?.itemId ?? {
            let newId = UUID().uuidString
            items[newId] = Item(itemId: newId, itemName: name)
            return newId
        }()

        if let idx = _entryIndex(listId: listId, itemId: itemId) {
            entries[idx].isMaskedHidden = false  // un-hide if previously masked
        } else {
            entries.append(ListEntry(listId: listId, itemId: itemId))
        }
        saveData()
    }

    /// Toggle check state. For inherited items, a local fork entry is created.
    func toggleItem(itemId: String, in listId: String) {
        if let idx = _entryIndex(listId: listId, itemId: itemId) {
            entries[idx].isChecked.toggle()
        } else if _inheritedFromAncestor(listId: listId, itemId: itemId) {
            entries.append(ListEntry(listId: listId, itemId: itemId, isChecked: true))
        }
        saveData()
    }

    /// Rename an item within a list context.
    /// For inherited items this creates a local customNameOverride (fork).
    func editItem(itemId: String, in listId: String, newName: String) {
        guard !newName.isEmpty else { return }
        let inherited = _inheritedFromAncestor(listId: listId, itemId: itemId)

        if let idx = _entryIndex(listId: listId, itemId: itemId) {
            if entries[idx].customNameOverride != nil || inherited {
                entries[idx].customNameOverride = newName
                entries[idx].isMaskedHidden = false
            } else {
                items[itemId]?.itemName = newName  // direct item — update master catalog
            }
        } else if inherited {
            entries.append(ListEntry(listId: listId, itemId: itemId, customNameOverride: newName))
        }
        saveData()
    }

    /// Returns items that are masked/hidden in this list (can be restored).
    func hiddenItems(listId: String) -> [DisplayItem] {
        entries
            .filter { $0.listId == listId && $0.isMaskedHidden }
            .compactMap { entry in
                let name = entry.customNameOverride ?? items[entry.itemId]?.itemName ?? "Unknown"
                return DisplayItem(itemId: entry.itemId, name: name, isChecked: false, isInherited: true)
            }
    }

    /// Restores a masked/hidden item so it is visible again in this list.
    func restoreItem(itemId: String, in listId: String) {
        if let idx = _entryIndex(listId: listId, itemId: itemId) {
            entries[idx].isMaskedHidden = false
            entries[idx].customNameOverride = nil
            entries[idx].isChecked = false
        }
        saveData()
    }

    /// Remove an item from a list.
    /// Inherited items are masked (hidden locally, parent unaffected).
    /// Direct items are deleted and their descendant forks are purged.
    func removeItem(itemId: String, from listId: String) {
        let inherited = _inheritedFromAncestor(listId: listId, itemId: itemId)

        if let idx = _entryIndex(listId: listId, itemId: itemId) {
            if entries[idx].isMaskedHidden { return }
            if inherited {
                entries[idx].isMaskedHidden = true
                entries[idx].customNameOverride = nil
                entries[idx].isChecked = false
            } else {
                entries.remove(at: idx)
                _purgeDescendantForks(listId: listId, itemId: itemId)
            }
        } else if inherited {
            entries.append(ListEntry(listId: listId, itemId: itemId, isMaskedHidden: true))
        }
        saveData()
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private func _entryIndex(listId: String, itemId: String) -> Int? {
        entries.firstIndex { $0.listId == listId && $0.itemId == itemId }
    }

    private func _inheritedFromAncestor(listId: String, itemId: String) -> Bool {
        var pointer = lists[listId]?.parentId
        var visited: Set<String> = [listId]
        while let p = pointer, !visited.contains(p) {
            visited.insert(p)
            if let idx = _entryIndex(listId: p, itemId: itemId) {
                return !entries[idx].isMaskedHidden
            }
            pointer = lists[p]?.parentId
        }
        return false
    }

    private func _purgeDescendantForks(listId: String, itemId: String) {
        for child in lists.values where child.parentId == listId {
            if _entryIndex(listId: child.listId, itemId: itemId) != nil,
               !_inheritedFromAncestor(listId: child.listId, itemId: itemId) {
                entries.removeAll { $0.listId == child.listId && $0.itemId == itemId }
            }
            _purgeDescendantForks(listId: child.listId, itemId: itemId)
        }
    }

    private func _topoSort(_ input: [GroceryList]) -> [GroceryList] {
        var sorted: [GroceryList] = []
        var remaining = input
        while !remaining.isEmpty {
            let doneIds = Set(sorted.map { $0.listId })
            let ready = remaining.filter { $0.parentId == nil || doneIds.contains($0.parentId!) }
            if ready.isEmpty { sorted.append(contentsOf: remaining); break }
            sorted.append(contentsOf: ready)
            let readyIds = Set(ready.map { $0.listId })
            remaining.removeAll { readyIds.contains($0.listId) }
        }
        return sorted
    }

    private func _autoName() -> String {
        let existing = Set(lists.values.map { $0.listName })
        var n = 1
        while existing.contains("List\(n)") { n += 1 }
        return "List\(n)"
    }

    private func _sha256(_ text: String) -> String {
        let hash = SHA256.hash(data: Data(text.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // ── Persistence ───────────────────────────────────────────────────────────

    private struct StoredDB: Codable {
        var lists:   [GroceryList]
        var items:   [Item]
        var entries: [ListEntry]
        var users:   [AppUser]
    }

    /// Save locally (always) then push to server in the background (best-effort).
    func saveData() {
        let db = StoredDB(lists: Array(lists.values), items: Array(items.values),
                          entries: entries, users: Array(users.values))
        if let data = try? JSONEncoder().encode(db) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        // Only push to server for authenticated (non-guest) users
        if network != nil && !isGuest && currentUser != nil {
            Task { await pushToServer() }
        }
    }

    private func loadData() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let db = try? JSONDecoder().decode(StoredDB.self, from: data) else { return }
        _applyDB(db)
    }

    // ── Server sync ───────────────────────────────────────────────────────────

    /// Quick connectivity check (no data fetched, used on login screen).
    @MainActor
    func checkServerHealth() async {
        guard let net = network else { serverStatus = .notConfigured; return }
        serverStatus = .syncing
        do {
            try await net.checkHealth()
            serverStatus = .ok
        } catch {
            serverStatus = .error(error.localizedDescription)
        }
    }

    /// Pull this user's state from the server and replace local state.
    @MainActor
    func syncFromServer() async {
        guard let net = network, let userId = currentUser?.username else { return }
        serverStatus = .syncing
        do {
            let state = try await net.fetchState(userId: userId)
            let db = StoredDB(lists: state.lists, items: state.items,
                               entries: state.entries, users: state.users)
            _applyDB(db)
            if let data = try? JSONEncoder().encode(db) {
                UserDefaults.standard.set(data, forKey: storageKey)
            }
            // Restore currentUser from synced data
            if let synced = users[userId] { currentUser = synced }
            serverStatus = .ok
        } catch {
            serverStatus = .error(error.localizedDescription)
        }
    }

    /// Push this user's state to server.
    private func pushToServer() async {
        guard let net = network, let userId = currentUser?.username else { return }
        let state = ServerState(lists: Array(lists.values), items: Array(items.values),
                                entries: entries, users: Array(users.values))
        do {
            try await net.pushState(state, userId: userId)
            await MainActor.run { serverStatus = .ok }
        } catch {
            await MainActor.run { serverStatus = .error(error.localizedDescription) }
        }
    }

    private func _applyDB(_ db: StoredDB) {
        lists   = [:]
        items   = [:]
        users   = [:]
        for l in db.lists  { lists[l.listId]   = l }
        for i in db.items  { items[i.itemId]   = i }
        for u in db.users  { users[u.username] = u }
        entries = db.entries
    }
}
