import Foundation

enum BookFormat: String, Codable, CaseIterable, Identifiable {
    case hardback = "Hardback"
    case paperback = "Paperback"
    case ebook = "eBook"
    case audiobook = "Audiobook"

    var id: String { rawValue }

    var ownedListKey: String { "[DJ] Owned · \(rawValue)" }
    var wantListKey: String { "[DJ] Want · \(rawValue)" }

    var icon: String {
        switch self {
        case .hardback: return "book.closed.fill"
        case .paperback: return "book.fill"
        case .ebook: return "ipad"
        case .audiobook: return "headphones"
        }
    }

    /// Attempt to map a Hardcover edition_format string to a BookFormat
    static func from(editionFormat: String?) -> BookFormat? {
        guard let format = editionFormat?.lowercased() else { return nil }
        switch format {
        case "hardcover", "hardback":
            return .hardback
        case "paperback", "mass_market_paperback", "mass market paperback":
            return .paperback
        case "ebook", "kindle", "digital":
            return .ebook
        case "audiobook", "audio", "audio cd":
            return .audiobook
        default:
            return nil
        }
    }
}
