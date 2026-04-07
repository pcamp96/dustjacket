import Foundation
import SwiftData

@MainActor
final class LibraryManager: ObservableObject {
    static let shared = LibraryManager()

    @Published var books: [Book] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var hasMorePages = true

    private var hardcoverService: HardcoverServiceProtocol?
    private var modelContext: ModelContext?
    private var currentOffset = 0
    private let pageSize = 50

    private init() {}

    func configure(service: HardcoverServiceProtocol, context: ModelContext) {
        self.hardcoverService = service
        self.modelContext = context
    }

    // MARK: - Fetch

    func fetchLibrary(refresh: Bool = false) async {
        guard let service = hardcoverService else { return }
        guard !isLoading else { return }

        if refresh {
            currentOffset = 0
            hasMorePages = true
        }

        isLoading = refresh || books.isEmpty
        errorMessage = nil

        do {
            let userBooks = try await service.getUserBooks(statusId: nil, limit: pageSize, offset: 0)
            let mapped = userBooks.map { Book(from: $0) }
            books = mapped
            currentOffset = mapped.count
            hasMorePages = mapped.count >= pageSize

            // Cache locally
            cacheBooks(mapped)
        } catch {
            errorMessage = error.localizedDescription
            // Fall back to cached data
            loadFromCache()
        }

        isLoading = false
    }

    func loadMoreIfNeeded(currentBook: Book) async {
        guard hasMorePages, !isLoadingMore else { return }
        guard let service = hardcoverService else { return }

        // Trigger when we're near the end
        guard let index = books.firstIndex(where: { $0.id == currentBook.id }),
              index >= books.count - 5 else { return }

        isLoadingMore = true

        do {
            let userBooks = try await service.getUserBooks(statusId: nil, limit: pageSize, offset: currentOffset)
            let mapped = userBooks.map { Book(from: $0) }

            // Deduplicate
            let existingIds = Set(books.map(\.id))
            let newBooks = mapped.filter { !existingIds.contains($0.id) }

            books.append(contentsOf: newBooks)
            currentOffset += mapped.count
            hasMorePages = mapped.count >= pageSize

            cacheBooks(newBooks)
        } catch {
            // Silently fail on pagination errors
        }

        isLoadingMore = false
    }

    // MARK: - Filtering

    func filteredBooks(ownership: OwnershipType?, format: BookFormat?) -> [Book] {
        // For now, return all books. Full list-based filtering requires list membership data
        // which we'll enhance when the list mappings are loaded.
        books
    }

    func currentlyReading() -> [Book] {
        books.filter { $0.statusId == 2 }
    }

    func recentlyAdded(limit: Int = 10) -> [Book] {
        Array(books.prefix(limit))
    }

    // MARK: - Optimistic Updates

    func addBookOptimistically(_ book: Book) {
        guard !books.contains(where: { $0.id == book.id }) else { return }
        books.insert(book, at: 0)
    }

    func removeBookOptimistically(id: Int) {
        books.removeAll { $0.id == id }
    }

    func updateBookStatusOptimistically(bookId: Int, statusId: Int) {
        guard let index = books.firstIndex(where: { $0.id == bookId }) else { return }
        let old = books[index]
        books[index] = Book(
            id: old.id, title: old.title, authorNames: old.authorNames,
            coverURL: old.coverURL, slug: old.slug, pageCount: old.pageCount,
            isbn13: old.isbn13, seriesID: old.seriesID, seriesName: old.seriesName,
            seriesPosition: old.seriesPosition, statusId: statusId,
            rating: old.rating, userBookId: old.userBookId
        )
    }

    func updateBookRatingOptimistically(bookId: Int, rating: Double) {
        guard let index = books.firstIndex(where: { $0.id == bookId }) else { return }
        let old = books[index]
        books[index] = Book(
            id: old.id, title: old.title, authorNames: old.authorNames,
            coverURL: old.coverURL, slug: old.slug, pageCount: old.pageCount,
            isbn13: old.isbn13, seriesID: old.seriesID, seriesName: old.seriesName,
            seriesPosition: old.seriesPosition, statusId: old.statusId,
            rating: rating, userBookId: old.userBookId
        )
    }

    // MARK: - Cache

    private func cacheBooks(_ booksToCache: [Book]) {
        guard let context = modelContext else { return }
        for book in booksToCache {
            let cached = CachedBook(
                hardcoverID: book.id,
                title: book.title,
                authorNames: book.authorNames,
                coverURL: book.coverURL,
                isbn13: book.isbn13,
                pageCount: book.pageCount,
                slug: book.slug,
                seriesID: book.seriesID,
                seriesName: book.seriesName,
                seriesPosition: book.seriesPosition,
                hardcoverStatusId: book.statusId,
                rating: book.rating,
                userBookId: book.userBookId
            )
            context.insert(cached)
        }
        try? context.save()
    }

    private func loadFromCache() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<CachedBook>(
            sortBy: [SortDescriptor(\.lastSynced, order: .reverse)]
        )
        if let cached = try? context.fetch(descriptor) {
            books = cached.map { Book(from: $0) }
        }
    }
}
