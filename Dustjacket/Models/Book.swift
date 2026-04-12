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
    let editionId: Int?
    let editionPageCount: Int?     // pages from user's specific edition
    let editionFormat: String?     // e.g. "Unabridged Audiobook", "Hardback", etc.
    let lastReadAt: String?        // ISO date of latest reading progress update

    /// Whether the selected edition is an audiobook
    var isAudiobook: Bool {
        guard let fmt = editionFormat?.lowercased() else { return false }
        return fmt.contains("audio") || fmt.contains("audible")
    }

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

    /// The effective page count — edition-specific if available, otherwise generic
    var effectivePageCount: Int? {
        editionPageCount ?? pageCount
    }

    /// Best available progress as a 0-1 fraction
    var progressFraction: Double? {
        if let pct = progressPercent, pct > 0 {
            return pct / 100.0
        }
        if let pages = currentProgress, let total = effectivePageCount, total > 0 {
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
            if let total = effectivePageCount {
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

    var needsDetailHydration: Bool {
        slug == nil || pageCount == nil || authorNames.isEmpty
    }

    /// Create a copy with modified fields
    func with(
        coverURL: String?? = nil,
        statusId: Int?? = nil,
        rating: Double?? = nil,
        userBookId: Int?? = nil,
        currentProgress: Int?? = nil,
        progressPercent: Double?? = nil,
        progressSeconds: Int?? = nil,
        editionId: Int?? = nil,
        editionPageCount: Int?? = nil,
        editionFormat: String?? = nil
    ) -> Book {
        Book(
            id: id, title: title, authorNames: authorNames,
            coverURL: coverURL ?? self.coverURL, slug: slug, pageCount: pageCount,
            isbn13: isbn13, seriesID: seriesID, seriesName: seriesName,
            seriesPosition: seriesPosition,
            statusId: statusId ?? self.statusId,
            rating: rating ?? self.rating,
            userBookId: userBookId ?? self.userBookId,
            currentProgress: currentProgress ?? self.currentProgress,
            progressPercent: progressPercent ?? self.progressPercent,
            progressSeconds: progressSeconds ?? self.progressSeconds,
            editionId: editionId ?? self.editionId,
            editionPageCount: editionPageCount ?? self.editionPageCount,
            editionFormat: editionFormat ?? self.editionFormat,
        lastReadAt: self.lastReadAt
        )
    }

    func merged(with other: Book) -> Book {
        Book(
            id: id,
            title: other.title.isEmpty ? title : other.title,
            authorNames: other.authorNames.isEmpty ? authorNames : other.authorNames,
            coverURL: other.coverURL ?? coverURL,
            slug: other.slug ?? slug,
            pageCount: other.pageCount ?? pageCount,
            isbn13: other.isbn13 ?? isbn13,
            seriesID: other.seriesID ?? seriesID,
            seriesName: other.seriesName ?? seriesName,
            seriesPosition: other.seriesPosition ?? seriesPosition,
            statusId: other.statusId ?? statusId,
            rating: other.rating ?? rating,
            userBookId: other.userBookId ?? userBookId,
            currentProgress: other.currentProgress ?? currentProgress,
            progressPercent: other.progressPercent ?? progressPercent,
            progressSeconds: other.progressSeconds ?? progressSeconds,
            editionId: other.editionId ?? editionId,
            editionPageCount: other.editionPageCount ?? editionPageCount,
            editionFormat: other.editionFormat ?? editionFormat,
            lastReadAt: other.lastReadAt ?? lastReadAt
        )
    }
}

// MARK: - Mapping from API

extension Book {
    init(from edition: Edition) {
        self.id = edition.bookId
        self.title = edition.displayTitle
        self.authorNames = edition.authorNames
        self.coverURL = edition.coverURL
        self.slug = edition.bookSlug
        self.pageCount = edition.pageCount
        self.isbn13 = edition.isbn13
        self.seriesID = edition.seriesID
        self.seriesName = edition.seriesName
        self.seriesPosition = edition.seriesPosition
        self.statusId = nil
        self.rating = nil
        self.userBookId = nil
        self.currentProgress = nil
        self.progressPercent = nil
        self.progressSeconds = nil
        self.editionId = edition.id != 0 ? edition.id : nil
        self.editionPageCount = edition.pageCount
        self.editionFormat = edition.format?.rawValue
        self.lastReadAt = nil
    }

    init(from userBook: HardcoverUserBook) {
        let hcBook = userBook.book
        self.id = hcBook.id
        self.title = hcBook.title
        self.authorNames = Self.extractAuthors(from: hcBook)
        self.coverURL = userBook.edition?.image?.url ?? hcBook.image?.url
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
        self.editionId = userBook.edition_id
        self.editionPageCount = userBook.edition?.pages
        self.editionFormat = userBook.edition?.edition_format
        self.lastReadAt = latestRead?.started_at

        // DEBUG: Remove after verifying sync works
        if userBook.status_id == 2 {
            print("[DJ-DEBUG] Currently Reading: \"\(hcBook.title)\"")
            print("  edition_id: \(String(describing: userBook.edition_id))")
            print("  edition object: \(String(describing: userBook.edition))")
            print("  edition pages: \(String(describing: userBook.edition?.pages))")
            print("  editionPageCount set to: \(String(describing: self.editionPageCount))")
            print("  user_book_reads: \(String(describing: userBook.user_book_reads))")
            print("  progress_pages: \(String(describing: latestRead?.progress_pages))")
            print("  progress_percent: \(String(describing: latestRead?.progress))")
            print("  progress_seconds: \(String(describing: latestRead?.progress_seconds))")
        }
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
        self.editionId = nil
        self.editionPageCount = nil
        self.editionFormat = nil
        self.lastReadAt = nil
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
        self.currentProgress = cached.currentProgress
        self.progressPercent = cached.progressPercent
        self.progressSeconds = cached.progressSeconds
        self.editionId = cached.editionId
        self.editionPageCount = cached.editionPageCount
        self.editionFormat = cached.editionFormat
        self.lastReadAt = nil
    }
}
