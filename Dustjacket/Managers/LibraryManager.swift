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
    /// Maps "bookId-listId" → list_book record ID (needed for delete_list_book)
    private var listBookIds: [String: Int] = [:]

    private(set) var hardcoverService: HardcoverServiceProtocol?
    private var modelContext: ModelContext?
    private var currentOffset = 0
    private let pageSize = 50
    private var lastRefreshTime: Date = .distantPast

    private init() {}

    func configure(service: HardcoverServiceProtocol, context: ModelContext) {
        self.hardcoverService = service
        self.modelContext = context
    }

    func resetState(clearConfiguration: Bool = false) {
        books = []
        isLoading = false
        isLoadingMore = false
        errorMessage = nil
        hasMorePages = true
        clearListMembershipState()
        currentOffset = 0
        lastRefreshTime = .distantPast

        if clearConfiguration {
            hardcoverService = nil
            modelContext = nil
        }
    }

    func clearListMembershipState() {
        bookListMembership = [:]
        listMappings = [:]
        reverseListMappings = [:]
        listBookIds = [:]
    }

    // MARK: - Fetch

    func fetchLibrary(refresh: Bool = false) async {
        print("[DJ-DEBUG] fetchLibrary called, refresh=\(refresh), hasService=\(hardcoverService != nil), isLoading=\(isLoading)")
        guard let service = hardcoverService else {
            print("[DJ-DEBUG] fetchLibrary: no service, returning early")
            return
        }
        guard !isLoading else {
            print("[DJ-DEBUG] fetchLibrary: already loading, returning early")
            return
        }

        // Debounce rapid refreshes (min 2 seconds between refreshes)
        if refresh && Date().timeIntervalSince(lastRefreshTime) < 2.0 {
            print("[DJ-DEBUG] fetchLibrary: debounced, too soon since last refresh")
            return
        }
        if refresh { lastRefreshTime = .now }

        if refresh {
            currentOffset = 0
            hasMorePages = true
        }

        isLoading = refresh || books.isEmpty
        errorMessage = nil

        do {
            print("[DJ-DEBUG] Calling getUserBooks...")
            let userBooks = try await service.getUserBooks(statusId: nil, limit: pageSize, offset: 0)
            print("[DJ-DEBUG] getUserBooks returned \(userBooks.count) books")
            let mapped = userBooks.map { Book(from: $0) }
            books = mapped
            currentOffset = mapped.count
            hasMorePages = mapped.count >= pageSize

            // Cache locally
            cacheBooks(mapped)

            // Load list memberships for filtering
            print("[DJ-DEBUG] Loading list memberships...")
            await loadListMemberships()
            print("[DJ-DEBUG] List memberships loaded, count=\(bookListMembership.count)")
        } catch {
            print("[DJ-DEBUG] fetchLibrary FAILED: \(error)")
            // On cancellation, keep current state — don't clobber with stale cache
            let isCancelled = (error as NSError).code == NSURLErrorCancelled
            if !isCancelled {
                errorMessage = error.localizedDescription
                // Only fall back to cache on real errors (not cancellations)
                if books.isEmpty {
                    loadFromCache()
                }
            }
        }

        isLoading = false
    }

    /// Load DJ list mappings from Swift Data + fetch which books are on which lists
    func loadListMemberships() async {
        guard let service = hardcoverService, let context = modelContext else { return }

        clearListMembershipState()

        // Load mappings from Swift Data
        let descriptor = FetchDescriptor<ListMapping>()
        guard let mappings = try? context.fetch(descriptor), !mappings.isEmpty else { return }

        for mapping in mappings {
            listMappings[mapping.djListKey] = mapping.hardcoverListId
            reverseListMappings[mapping.hardcoverListId] = mapping.djListKey
        }

        // Fetch all user lists with their book memberships
        do {
            let lists = try await service.getUserLists()
            var membership: [Int: Set<String>] = [:]
            let existingBookIds = Set(books.map(\.id))
            var newBooks: [Book] = []

            for list in lists {
                // Only process lists that are mapped to DJ lists
                guard let djKey = reverseListMappings[list.id] else { continue }
                guard let listBooks = list.list_books else { continue }

                for listBook in listBooks {
                    membership[listBook.book_id, default: []].insert(djKey)

                    // Track list_book record ID for deletions
                    if let lbId = listBook.id {
                        listBookIds["\(listBook.book_id)-\(list.id)"] = lbId
                    }

                    // If this book isn't in our library yet, add it from list data
                    if !existingBookIds.contains(listBook.book_id),
                       !newBooks.contains(where: { $0.id == listBook.book_id }),
                       let hcBook = listBook.book {
                        newBooks.append(Book(from: hcBook))
                    }
                }
            }

            bookListMembership = membership

            // Add list-only books to the library
            if !newBooks.isEmpty {
                books.append(contentsOf: newBooks)
            }
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

    /// Get the list_book record ID for a specific book on a specific list
    func listBookRecordId(bookId: Int, listId: Int) -> Int? {
        listBookIds["\(bookId)-\(listId)"]
    }

    func currentlyReading() -> [Book] {
        books.filter { $0.statusId == 2 }
            .sorted { ($0.lastReadAt ?? "") > ($1.lastReadAt ?? "") }
    }

    func recentlyAdded(limit: Int = 10) -> [Book] {
        Array(books.prefix(limit))
    }

    // MARK: - Optimistic Updates

    func book(withID bookId: Int) -> Book? {
        books.first { $0.id == bookId }
    }

    func upsertBook(_ book: Book) {
        let cachedBook: Book

        if let index = books.firstIndex(where: { $0.id == book.id }) {
            books[index] = books[index].merged(with: book)
            cachedBook = books[index]
        } else if book.userBookId != nil || book.statusId != nil {
            books.insert(book, at: 0)
            cachedBook = book
        } else {
            cachedBook = book
        }

        cacheBooks([cachedBook])
    }

    func addBookOptimistically(_ book: Book) {
        guard !books.contains(where: { $0.id == book.id }) else { return }
        books.insert(book, at: 0)
    }

    func removeBookOptimistically(id: Int) {
        books.removeAll { $0.id == id }
    }

    func updateBookStatusOptimistically(bookId: Int, statusId: Int) {
        guard let index = books.firstIndex(where: { $0.id == bookId }) else { return }
        books[index] = books[index].with(statusId: statusId)
    }

    /// Toggle a book on/off a DJ list (e.g., mark as Owned · Hardback)
    /// When adding to Owned, automatically removes from Want for same format (and vice versa)
    /// Pass the full Book if it might not be in the library yet (e.g., from scanner)
    func toggleBookOnDJList(bookId: Int, ownership: OwnershipType, format: BookFormat, book: Book? = nil) {
        let djKey = ownership.listKey(for: format)
        guard let listId = listMappings[djKey] else { return }

        let isCurrentlyOn = bookListMembership[bookId]?.contains(djKey) ?? false

        if isCurrentlyOn {
            // Remove from list
            bookListMembership[bookId]?.remove(djKey)
            if let listBookId = listBookIds["\(bookId)-\(listId)"] {
                SyncManager.shared.enqueueRemoveFromList(listBookId: listBookId)
                listBookIds.removeValue(forKey: "\(bookId)-\(listId)")
            }

            // If book has no more list memberships, remove from library
            if bookListMembership[bookId]?.isEmpty ?? true {
                books.removeAll { $0.id == bookId }
            }
        } else {
            // Add to list
            bookListMembership[bookId, default: []].insert(djKey)
            SyncManager.shared.enqueueAddToList(bookId: bookId, listId: listId)

            // If book isn't in library yet, add it
            if let book, !books.contains(where: { $0.id == bookId }) {
                books.insert(book, at: 0)
            }

            // Auto-remove from the opposite ownership for the same format
            let oppositeOwnership: OwnershipType = ownership == .owned ? .want : .owned
            let oppositeKey = oppositeOwnership.listKey(for: format)
            if bookListMembership[bookId]?.contains(oppositeKey) == true,
               let oppositeListId = listMappings[oppositeKey],
               let oppositeListBookId = listBookIds["\(bookId)-\(oppositeListId)"] {
                bookListMembership[bookId]?.remove(oppositeKey)
                SyncManager.shared.enqueueRemoveFromList(listBookId: oppositeListBookId)
                listBookIds.removeValue(forKey: "\(bookId)-\(oppositeListId)")
            }
        }
    }

    func updateBookProgressOptimistically(bookId: Int, currentProgress: Int? = nil, progressPercent: Double? = nil, progressSeconds: Int? = nil) {
        guard let index = books.firstIndex(where: { $0.id == bookId }) else { return }
        books[index] = books[index].with(
            currentProgress: .some(currentProgress),
            progressPercent: .some(progressPercent),
            progressSeconds: .some(progressSeconds)
        )
    }

    func updateBookEditionOptimistically(bookId: Int, coverURL: String? = nil, editionId: Int, editionPageCount: Int?, editionFormat: String? = nil) {
        guard let index = books.firstIndex(where: { $0.id == bookId }) else { return }
        books[index] = books[index].with(
            coverURL: coverURL,
            editionId: editionId,
            editionPageCount: editionPageCount,
            editionFormat: .some(editionFormat)
        )
    }

    func updateBookRatingOptimistically(bookId: Int, rating: Double) {
        guard let index = books.firstIndex(where: { $0.id == bookId }) else { return }
        books[index] = books[index].with(rating: rating)
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
                userBookId: book.userBookId,
                editionId: book.editionId,
                currentProgress: book.currentProgress,
                progressPercent: book.progressPercent,
                progressSeconds: book.progressSeconds,
                editionPageCount: book.editionPageCount,
                editionFormat: book.editionFormat
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
