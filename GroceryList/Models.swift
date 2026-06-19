import SwiftUI

// MARK: - Stored entities (mirrors PostgreSQL schema)

/// Master item catalog — one row per unique product name.
struct Item: Codable {
    var itemId: String
    var itemName: String
}

/// Junction table — maps one item to one list with per-list state.
/// isMaskedHidden: true  → item is hidden in this list but still lives in the parent.
/// customNameOverride    → local rename that doesn't affect the master item or other lists.
struct ListEntry: Codable {
    var listId: String
    var itemId: String
    var isChecked: Bool
    var isMaskedHidden: Bool
    var customNameOverride: String?

    init(listId: String, itemId: String, isChecked: Bool = false,
         isMaskedHidden: Bool = false, customNameOverride: String? = nil) {
        self.listId = listId
        self.itemId = itemId
        self.isChecked = isChecked
        self.isMaskedHidden = isMaskedHidden
        self.customNameOverride = customNameOverride
    }
}

/// Grocery list tree node. parentId links form the inheritance chain.
struct GroceryList: Codable, Identifiable {
    var listId: String
    var listName: String
    var parentId: String?
    var userId: String?
    var theme: ListTheme
    var createdDate: String

    var id: String { listId }

    init(listId: String = UUID().uuidString, listName: String, parentId: String? = nil,
         userId: String? = nil, theme: ListTheme = .natural, createdDate: String = "") {
        self.listId = listId
        self.listName = listName
        self.parentId = parentId
        self.userId = userId
        self.theme = theme
        self.createdDate = createdDate
    }
}

struct AppUser: Codable {
    var username: String   // serves as primary key (email)
    var passwordHash: String
    var firstName: String
    var lastName: String
    var zipCode: String

    init(username: String = "", passwordHash: String = "",
         firstName: String = "", lastName: String = "", zipCode: String = "") {
        self.username = username
        self.passwordHash = passwordHash
        self.firstName = firstName
        self.lastName = lastName
        self.zipCode = zipCode
    }
}

// MARK: - Display model (computed, never stored)

/// The resolved view of a single item within a specific list context.
struct DisplayItem: Identifiable {
    var itemId: String
    var name: String
    var isChecked: Bool
    /// True if this item originates from an ancestor list.
    var isInherited: Bool

    var id: String { itemId }
}

// MARK: - Theme

enum ListTheme: String, Codable, CaseIterable {
    case natural, purple, green, teal, dark

    // Light: vibrant, saturated — dark enough for white text
    // Dark:  rich, deeply saturated — clearly distinct from light
    func backgroundColor(_ scheme: ColorScheme) -> Color {
        let dark = scheme == .dark
        switch self {
        case .natural: return dark ? Color(red: 0.10, green: 0.26, blue: 0.18) : Color(red: 0.20, green: 0.52, blue: 0.35)
        case .purple:  return dark ? Color(red: 0.22, green: 0.10, blue: 0.35) : Color(red: 0.48, green: 0.25, blue: 0.70)
        case .green:   return dark ? Color(red: 0.08, green: 0.28, blue: 0.14) : Color(red: 0.18, green: 0.58, blue: 0.30)
        case .teal:    return dark ? Color(red: 0.05, green: 0.24, blue: 0.26) : Color(red: 0.12, green: 0.52, blue: 0.56)
        case .dark:    return Color(red: 0.18, green: 0.18, blue: 0.22)
        }
    }

    // White text works on all backgrounds above
    func textColor(_ scheme: ColorScheme) -> Color { .white }

    func lineColor(_ scheme: ColorScheme) -> Color {
        Color.white.opacity(0.12)
    }

    func accentColor(_ scheme: ColorScheme) -> Color {
        switch self {
        case .natural: return Color(red: 0.62, green: 1.00, blue: 0.78)
        case .purple:  return Color(red: 0.88, green: 0.70, blue: 1.00)
        case .green:   return Color(red: 0.55, green: 1.00, blue: 0.70)
        case .teal:    return Color(red: 0.50, green: 0.98, blue: 0.96)
        case .dark:    return Color(red: 0.38, green: 0.80, blue: 0.60)
        }
    }

    var displayName: String { rawValue.capitalized }
}
