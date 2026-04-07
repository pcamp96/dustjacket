import Foundation
import SwiftData

@Model
final class CachedEdition {
    @Attribute(.unique) var hardcoverID: Int
    var bookHardcoverID: Int
    var title: String?
    var isbn13: String?
    var isbn10: String?
    var editionFormat: String?
    var pages: Int?
    var releaseDate: String?
    var coverURL: String?
    var lastSynced: Date

    init(
        hardcoverID: Int,
        bookHardcoverID: Int,
        title: String? = nil,
        isbn13: String? = nil,
        isbn10: String? = nil,
        editionFormat: String? = nil,
        pages: Int? = nil,
        releaseDate: String? = nil,
        coverURL: String? = nil,
        lastSynced: Date = .now
    ) {
        self.hardcoverID = hardcoverID
        self.bookHardcoverID = bookHardcoverID
        self.title = title
        self.isbn13 = isbn13
        self.isbn10 = isbn10
        self.editionFormat = editionFormat
        self.pages = pages
        self.releaseDate = releaseDate
        self.coverURL = coverURL
        self.lastSynced = lastSynced
    }
}
