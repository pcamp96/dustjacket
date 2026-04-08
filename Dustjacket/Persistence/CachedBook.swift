import Foundation
import SwiftData

@Model
final class CachedBook {
    @Attribute(.unique) var hardcoverID: Int
    var title: String
    var authorNames: [String]
    var coverURL: String?
    var isbn13: String?
    var pageCount: Int?
    var slug: String?
    var seriesID: Int?
    var seriesName: String?
    var seriesPosition: Double?
    var hardcoverStatusId: Int?
    var rating: Double?
    var userBookId: Int?
    var editionId: Int?
    var lastSynced: Date

    init(
        hardcoverID: Int,
        title: String,
        authorNames: [String] = [],
        coverURL: String? = nil,
        isbn13: String? = nil,
        pageCount: Int? = nil,
        slug: String? = nil,
        seriesID: Int? = nil,
        seriesName: String? = nil,
        seriesPosition: Double? = nil,
        hardcoverStatusId: Int? = nil,
        rating: Double? = nil,
        userBookId: Int? = nil,
        editionId: Int? = nil,
        lastSynced: Date = .now
    ) {
        self.hardcoverID = hardcoverID
        self.title = title
        self.authorNames = authorNames
        self.coverURL = coverURL
        self.isbn13 = isbn13
        self.pageCount = pageCount
        self.slug = slug
        self.seriesID = seriesID
        self.seriesName = seriesName
        self.seriesPosition = seriesPosition
        self.hardcoverStatusId = hardcoverStatusId
        self.rating = rating
        self.userBookId = userBookId
        self.editionId = editionId
        self.lastSynced = lastSynced
    }
}
