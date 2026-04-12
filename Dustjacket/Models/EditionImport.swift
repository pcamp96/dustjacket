import Foundation

enum ISBNImportSource: String, Codable, Sendable {
    case scanner
    case search

    var displayName: String {
        switch self {
        case .scanner:
            return "Scanner"
        case .search:
            return "Search"
        }
    }
}

struct MissingEditionDraft: Identifiable, Hashable, Sendable {
    let isbn: String
    let source: ISBNImportSource
    var title: String
    var authorNamesText: String
    var format: BookFormat?
    var pageCount: Int?
    var releaseYear: String

    var id: String { isbn }
}

struct PendingEditionImportStatus: Identifiable, Hashable, Sendable {
    let isbn: String
    let source: ISBNImportSource
    let title: String
    let authorNamesText: String
    let format: BookFormat?
    let pageCount: Int?
    let releaseYear: String
    let createdAt: Date
    let lastCheckedAt: Date?
    let lastError: String?

    var id: String { isbn }
}

enum ISBNLookupOutcome: Sendable {
    case found(Edition)
    case missing(MissingEditionDraft)
    case pending(PendingEditionImportStatus)
}

struct ISBNImportSubmissionResult: Sendable {
    let bookId: Int?
    let editionId: Int?
    let edition: Edition?
    let errors: [String]

    var wasAccepted: Bool {
        bookId != nil || editionId != nil || edition != nil
    }
}
