import Foundation
import SwiftData

@Model
final class PendingEditionImportRecord {
    @Attribute(.unique) var isbn: String
    var sourceRawValue: String
    var title: String
    var authorNamesText: String
    var formatRawValue: String?
    var pageCount: Int?
    var releaseYear: String
    var createdAt: Date
    var lastCheckedAt: Date?
    var lastError: String?

    init(
        isbn: String,
        sourceRawValue: String,
        title: String = "",
        authorNamesText: String = "",
        formatRawValue: String? = nil,
        pageCount: Int? = nil,
        releaseYear: String = "",
        createdAt: Date = .now,
        lastCheckedAt: Date? = nil,
        lastError: String? = nil
    ) {
        self.isbn = isbn
        self.sourceRawValue = sourceRawValue
        self.title = title
        self.authorNamesText = authorNamesText
        self.formatRawValue = formatRawValue
        self.pageCount = pageCount
        self.releaseYear = releaseYear
        self.createdAt = createdAt
        self.lastCheckedAt = lastCheckedAt
        self.lastError = lastError
    }
}
