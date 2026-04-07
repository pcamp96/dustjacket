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

    /// Maps bookId → set of DJ list keys the book belongs to (e.g. "[DJ] Owned · Hardback")
    @Published var bookListMembership: [Int: Set<String>] = [:]

    /// Maps DJ list key → Hardcover list ID
    private var listMappings: [String: Int] = [:]
    /// Maps Hardcover list ID → DJ list key (reverse lookup)
    private var reverseListMappings: [Int: String] = [:]

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

            // Load list memberships for filtering
            await loadListMemberships()
        } catch {
            errorMessage = error.localizedDescription
            // Fall back to cached data
            loadFromCache()
        }

        isLoading = false
    }

    /// Load DJ list mappings from Swift Data + fetch which books are on which lists
    func loadListMemberships() async {
        guard let service = hardcoverService, let context = modelContext else { return }

        // Load mappings from Swift Data
        let descriptor = FetchDescriptor<ListMapping>()
        guard let mappings = try? context.fetch(descriptor), !mappings.isEmpty else { return }

        listMappings = [:]
        reverseListMappings = [:]
        for mapping in mappings {
            listMappings[mapping.djListKey] = mapping.hardcoverListId
            reverseListMappings[mapping.hardcoverListId] = mapping.djListKey
        }

        // Fetch all user lists with their book memberships
        do {
            let lists = try await service.getUserLists()
            var membership: [Int: Set<String>] = [:]

            for list in lists {
                // Only process lists that are mapped to DJ lists
                guard let djKey = reverseListMappings[list.id] else { continue }
                guard let listBooks = list.list_books else { continue }

                for listBook in listBooks {
                    membership[listBook.book_id, default: []].insert(djKey)
                }
            }

            bookListMembership = membership
        } catch {
            // Non-fatal — filtering just won't work until next refresh
        }
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
        // If no list memberships loaded yet, fall back to showing all
        guard !bookListMembership.isEmpty else { return books }
        guard let ownership else { return books }

        return books.filter { book in
            let memberKeys = bookListMembership[book.id] ?? []
            if let format {
                // Filter by specific ownership + format
                return memberKeys.contains(ownership.listKey(for: format))
            } else {
                // Filter by ownership (any format)
                return BookFormat.allCases.contains { fmt in
                    memberKeys.contains(ownership.listKey(for: fmt))
                }
            }
        }
    }

    /// Get which DJ lists a specific book belongs to
    func djListsForBook(_ bookId: Int) -> Set<String> {
        bookListMembership[bookId] ?? []
    }

    /// Check if a book is on a specific DJ list
    func isBookOnList(_ bookId: Int, ownership: OwnershipType, format: BookFormat) -> Bool {
        let key = ownership.listKey(for: format)
        return bookListMembership[bookId]?.contains(key) ?? false
    }

    /// Get the Hardcover list ID for a DJ list key
    func hardcoverListId(for djListKey: String) -> Int? {
        listMappings[djListKey]
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

    /// Toggle a book on/off a DJ list (e.g., mark as Owned · Hardback)
    /// When adding to Owned, automatically removes from Want for same format (and vice versa)
    func toggleBookOnDJList(bookId: Int, ownership: OwnershipType, format: BookFormat) {
        let djKey = ownership.listKey(for: format)
        guard let listId = listMappings[djKey] else { return }

        let isCurrentlyOn = bookListMembership[bookId]?.contains(djKey) ?? false

        if isCurrentlyOn {
            // Remove from list
            bookListMembership[bookId]?.remove(djKey)
            SyncManager.shared.enqueueRemoveFromList(bookId: bookId, listId: listId)
        } else {
            // Add to list
            bookListMembership[bookId, default: []].insert(djKey)
            SyncManager.shared.enqueueAddToList(bookId: bookId, listId: listId)

            // Auto-remove from the opposite ownership for the same format
            let oppositeOwnership: OwnershipType = ownership == .owned ? .want : .owned
            let oppositeKey = oppositeOwnership.listKey(for: format)
            if bookListMembership[bookId]?.contains(oppositeKey) == true,
               let oppositeListId = listMappings[oppositeKey] {
                bookListMembership[bookId]?.remove(oppositeKey)
                SyncManager.shared.enqueueRemoveFromList(bookId: bookId, listId: oppositeListId)
            }
        }
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
