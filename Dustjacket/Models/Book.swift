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
    let userBookId: Int?
    let currentProgress: Int?      // pages read
    let progressPercent: Double?   // 0-100 percentage
    let progressSeconds: Int?      // audio seconds listened

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

    /// Best available progress as a 0-1 fraction
    var progressFraction: Double? {
        if let pct = progressPercent, pct > 0 {
            return pct / 100.0
        }
        if let pages = currentProgress, let total = pageCount, total > 0 {
            return Double(pages) / Double(total)
        }
        return nil
    }

    /// Human-readable progress string
    var progressLabel: String? {
        if let secs = progressSeconds, secs > 0 {
            let hours = secs / 3600
            let mins = (secs % 3600) / 60
            return "\(hours)h \(mins)m listened"
        }
        if let pct = progressPercent, pct > 0 {
            return "\(Int(pct))% done"
        }
        if let pages = currentProgress, pages > 0 {
            if let total = pageCount {
                return "\(pages) of \(total) pages"
            }
            return "Page \(pages)"
        }
        return nil
    }

    var hardcoverURL: URL? {
        guard let slug else { return nil }
        return URL(string: "https://hardcover.app/books/\(slug)")
    }

    /// Create a copy with modified fields
    func with(
        statusId: Int?? = nil,
        rating: Double?? = nil,
        userBookId: Int?? = nil,
        currentProgress: Int?? = nil,
        progressPercent: Double?? = nil,
        progressSeconds: Int?? = nil
    ) -> Book {
        Book(
            id: id, title: title, authorNames: authorNames,
            coverURL: coverURL, slug: slug, pageCount: pageCount,
            isbn13: isbn13, seriesID: seriesID, seriesName: seriesName,
            seriesPosition: seriesPosition,
            statusId: statusId ?? self.statusId,
            rating: rating ?? self.rating,
            userBookId: userBookId ?? self.userBookId,
            currentProgress: currentProgress ?? self.currentProgress,
            progressPercent: progressPercent ?? self.progressPercent,
            progressSeconds: progressSeconds ?? self.progressSeconds
        )
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
        self.userBookId = userBook.id
        let latestRead = userBook.user_book_reads?.first
        self.currentProgress = latestRead?.progress_pages
        self.progressPercent = latestRead?.progress
        self.progressSeconds = latestRead?.progress_seconds
    }

    init(from hcBook: HardcoverBook, statusId: Int? = nil, rating: Double? = nil, userBookId: Int? = nil) {
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
        self.userBookId = userBookId
        self.currentProgress = nil
        self.progressPercent = nil
        self.progressSeconds = nil
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
        self.userBookId = cached.userBookId
        self.currentProgress = nil
        self.progressPercent = nil
        self.progressSeconds = nil
    }
}
