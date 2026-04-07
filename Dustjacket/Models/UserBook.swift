import Foundation

struct UserBook: Identifiable, Codable, Hashable, Sendable {
    let id: Int
    let statusId: Int?
    let rating: Double?
    let createdAt: String?
    let book: Book
}

// MARK: - Reading Status

enum ReadingStatus: Int, Codable, CaseIterable, Identifiable {
    case wantToRead = 1
    case currentlyReading = 2
    case read = 3
    case didNotFinish = 5

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .wantToRead: return "Want to Read"
        case .currentlyReading: return "Currently Reading"
        case .read: return "Read"
        case .didNotFinish: return "Did Not Finish"
        }
    }

    var icon: String {
        switch self {
        case .wantToRead: return "bookmark"
        case .currentlyReading: return "book.fill"
        case .read: return "checkmark.circle.fill"
        case .didNotFinish: return "xmark.circle"
        }
    }
}
