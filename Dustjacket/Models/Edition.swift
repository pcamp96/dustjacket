import Foundation

struct Edition: Identifiable, Codable, Hashable, Sendable {
    let id: Int
    let bookId: Int
    let title: String?
    let isbn13: String?
    let isbn10: String?
    let format: BookFormat?
    let pageCount: Int?
    let releaseDate: String?
    let coverURL: String?
    let bookTitle: String?
    let bookCoverURL: String?
    let bookSlug: String?
    let authorNames: [String]
    let seriesID: Int?
    let seriesName: String?
    let seriesPosition: Double?
}

extension Edition {
    var displayTitle: String {
        bookTitle ?? title ?? "Unknown Title"
    }

    var displayISBN: String? {
        isbn13 ?? isbn10
    }

    init(from hcEdition: HardcoverEdition) {
        self.id = hcEdition.id
        self.bookId = hcEdition.book?.id ?? 0
        self.title = hcEdition.title
        self.isbn13 = hcEdition.isbn_13
        self.isbn10 = hcEdition.isbn_10
        self.format = BookFormat.from(editionFormat: hcEdition.edition_format)
        self.pageCount = hcEdition.pages
        self.releaseDate = hcEdition.release_date
        self.coverURL = hcEdition.image?.url ?? hcEdition.book?.image?.url
        self.bookTitle = hcEdition.book?.title
        self.bookCoverURL = hcEdition.book?.image?.url
        self.bookSlug = hcEdition.book?.slug

        if let contributions = hcEdition.book?.contributions {
            self.authorNames = contributions.map(\.author.name)
        } else if let cached = hcEdition.book?.cached_contributors?.author {
            self.authorNames = cached.compactMap(\.name)
        } else {
            self.authorNames = []
        }

        self.seriesID = hcEdition.book?.book_series?.first?.series.id
        self.seriesName = hcEdition.book?.book_series?.first?.series.name
        self.seriesPosition = hcEdition.book?.book_series?.first?.position
    }
}
