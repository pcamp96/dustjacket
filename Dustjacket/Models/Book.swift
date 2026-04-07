import Foundation

struct Book: Identifiable, Codable, Hashable, Sendable {
    let id: Int
    let title: String
    let authorNames: [String]
    let coverURL: String?
    let slug: String?
    let pageCount: Int?
    let isbn13: String?
    let seriesID: Int?
    let seriesName: String?
    let seriesPosition: Double?
    let statusId: Int?
    let rating: Double?

    var displayAuthor: String {
        authorNames.joined(separator: ", ")
    }

    var statusLabel: String? {
        guard let statusId else { return nil }
        switch statusId {
        case 1: return "Want to Read"
        case 2: return "Currently Reading"
        case 3: return "Read"
        case 5: return "Did Not Finish"
        default: return nil
        }
    }

    var hardcoverURL: URL? {
        guard let slug else { return nil }
        return URL(string: "https://hardcover.app/books/\(slug)")
    }
}

// MARK: - Mapping from API

extension Book {
    init(from userBook: HardcoverUserBook) {
        let hcBook = userBook.book
        self.id = hcBook.id
        self.title = hcBook.title
        self.authorNames = Self.extractAuthors(from: hcBook)
        self.coverURL = hcBook.image?.url
        self.slug = hcBook.slug
        self.pageCount = hcBook.pages
        self.isbn13 = nil
        self.seriesID = hcBook.book_series?.first?.series.id
        self.seriesName = hcBook.book_series?.first?.series.name
        self.seriesPosition = hcBook.book_series?.first?.position
        self.statusId = userBook.status_id
        self.rating = userBook.rating
    }

    init(from hcBook: HardcoverBook, statusId: Int? = nil, rating: Double? = nil) {
        self.id = hcBook.id
        self.title = hcBook.title
        self.authorNames = Self.extractAuthors(from: hcBook)
        self.coverURL = hcBook.image?.url
        self.slug = hcBook.slug
        self.pageCount = hcBook.pages
        self.isbn13 = nil
        self.seriesID = hcBook.book_series?.first?.series.id
        self.seriesName = hcBook.book_series?.first?.series.name
        self.seriesPosition = hcBook.book_series?.first?.position
        self.statusId = statusId
        self.rating = rating
    }

    private static func extractAuthors(from book: HardcoverBook) -> [String] {
        // Prefer cached_contributors (faster), fall back to contributions
        if let cached = book.cached_contributors?.author {
            return cached.compactMap(\.name)
        }
        if let contributions = book.contributions {
            return contributions.map(\.author.name)
        }
        return []
    }
}

// MARK: - Mapping from Cache

extension Book {
    init(from cached: CachedBook) {
        self.id = cached.hardcoverID
        self.title = cached.title
        self.authorNames = cached.authorNames
        self.coverURL = cached.coverURL
        self.slug = cached.slug
        self.pageCount = cached.pageCount
        self.isbn13 = cached.isbn13
        self.seriesID = cached.seriesID
        self.seriesName = cached.seriesName
        self.seriesPosition = cached.seriesPosition
        self.statusId = cached.hardcoverStatusId
        self.rating = cached.rating
    }
}
