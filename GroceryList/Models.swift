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

    private static var isDark: Bool {
        UserDefaults.standard.bool(forKey: "isDarkMode")
    }

    var backgroundColor: Color {
        switch self {
        case .natural: return Self.isDark ? Color(red: 0.15, green: 0.13, blue: 0.11) : Color(red: 0.98, green: 0.96, blue: 0.88)
        case .purple:  return Self.isDark ? Color(red: 0.14, green: 0.09, blue: 0.20) : Color(red: 0.88, green: 0.78, blue: 0.97)
        case .green:   return Self.isDark ? Color(red: 0.07, green: 0.15, blue: 0.09) : Color(red: 0.78, green: 0.94, blue: 0.82)
        case .teal:    return Self.isDark ? Color(red: 0.05, green: 0.14, blue: 0.15) : Color(red: 0.74, green: 0.92, blue: 0.92)
        case .dark:    return Color(red: 0.20, green: 0.20, blue: 0.25)
        }
    }

    var lineColor: Color {
        (self == .dark || Self.isDark)
            ? Color.white.opacity(0.10)
            : Color(red: 0.38, green: 0.52, blue: 0.78).opacity(0.55)
    }

    var textColor: Color {
        (self == .dark || Self.isDark) ? .white : Color(red: 0.1, green: 0.1, blue: 0.15)
    }

    var accentColor: Color {
        switch self {
        case .natural: return Self.isDark ? Color(red: 0.25, green: 0.75, blue: 0.52) : Color(red: 0.15, green: 0.55, blue: 0.38)
        case .purple:  return Self.isDark ? Color(red: 0.72, green: 0.45, blue: 0.95) : Color(red: 0.50, green: 0.18, blue: 0.78)
        case .green:   return Self.isDark ? Color(red: 0.20, green: 0.72, blue: 0.35) : Color(red: 0.12, green: 0.52, blue: 0.22)
        case .teal:    return Self.isDark ? Color(red: 0.15, green: 0.72, blue: 0.75) : Color(red: 0.08, green: 0.50, blue: 0.52)
        case .dark:    return Color(red: 0.38, green: 0.80, blue: 0.60)
        }
    }

    var displayName: String { rawValue.capitalized }
}
