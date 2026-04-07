import Foundation

enum OwnershipType: String, Codable, CaseIterable, Identifiable {
    case owned = "Owned"
    case want = "Want"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .owned: return "checkmark.circle.fill"
        case .want: return "heart.fill"
        }
    }

    func listKey(for format: BookFormat) -> String {
        switch self {
        case .owned: return format.ownedListKey
        case .want: return format.wantListKey
        }
    }

    /// All 8 DJ list keys (4 per ownership type)
    static var allListKeys: [String] {
        OwnershipType.allCases.flatMap { ownership in
            BookFormat.allCases.map { format in
                ownership.listKey(for: format)
            }
        }
    }
}
