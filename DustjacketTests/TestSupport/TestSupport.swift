import Foundation
import SwiftData
@testable import Dustjacket

final class RecordingGraphQLClient: GraphQLClientProtocol, @unchecked Sendable {
    var lastQuery: String?
    var lastVariables: [String: Any]?
    var lastResponseKeyPath: String?
    var nextError: Error?
    var nextResult: Any

    init(nextResult: Any) {
        self.nextResult = nextResult
    }

    func execute<T: Decodable>(
        query: String,
        variables: [String: Any]?,
        responseKeyPath: String,
        responseType: T.Type
    ) async throws -> T {
        lastQuery = query
        lastVariables = variables
        lastResponseKeyPath = responseKeyPath

        if let nextError {
            throw nextError
        }

        guard let typedResult = nextResult as? T else {
            fatalError("Unexpected result type: \(T.self)")
        }

        return typedResult
    }
}

final class TestHardcoverService: HardcoverServiceProtocol, @unchecked Sendable {
    var validateTokenResult = makeUser()
    var searchBooksResult: [HardcoverSearchResult] = []
    var editionByISBNResult: [HardcoverEdition] = []
    var userListsResults: [[HardcoverList]] = []
    var userBooksResult: [HardcoverUserBook] = []
    var createdLists: [HardcoverList] = []
    var trendingResult: [HardcoverTrendingBook] = []
    var insertUserBookResult = makeUserBook()
    var updateUserBookResult = makeUserBook()
    var goalsResult: [HardcoverGoal] = []
    var insertGoalResult = 1
    var insertReadResult = 1
    var editionsByBookResult: [HardcoverEdition] = []

    var addBookToListError: Error?
    var removeBookFromListError: Error?
    var insertUserBookError: Error?
    var updateUserBookError: Error?
    var deleteUserBookError: Error?
    var insertReadError: Error?
    var updateReviewError: Error?
    var insertJournalError: Error?

    var addBookToListCalls: [(bookId: Int, listId: Int)] = []
    var editionByISBNCalls: [String] = []
    var removeBookFromListCalls: [Int] = []
    var insertUserBookCalls: [(bookId: Int, statusId: Int)] = []
    var updateUserBookCalls: [(id: Int, statusId: Int?, rating: Double?, editionId: Int?)] = []
    var deleteUserBookCalls: [Int] = []
    var insertReadCalls: [(userBookId: Int, progressPages: Int?, progressPercent: Double?, progressSeconds: Int?)] = []
    var updateReviewCalls: [(id: Int, reviewText: String, hasSpoilers: Bool)] = []
    var insertJournalCalls: [(bookId: Int, event: String, entry: String?, privacySettingId: Int)] = []

    func validateToken() async throws -> HardcoverUser {
        validateTokenResult
    }

    func searchBooks(query: String, page: Int, perPage: Int) async throws -> [HardcoverSearchResult] {
        searchBooksResult
    }

    func getEditionByISBN(_ isbn: String) async throws -> [HardcoverEdition] {
        editionByISBNCalls.append(isbn)
        return editionByISBNResult
    }

    func getUserLists() async throws -> [HardcoverList] {
        if !userListsResults.isEmpty {
            return userListsResults.removeFirst()
        }
        return []
    }

    func getUserBooks(statusId: Int?, limit: Int, offset: Int) async throws -> [HardcoverUserBook] {
        userBooksResult
    }

    func createList(name: String) async throws -> HardcoverList {
        if !createdLists.isEmpty {
            return createdLists.removeFirst()
        }
        return makeList(id: Int.random(in: 1000...9999), name: name)
    }

    func addBookToList(bookId: Int, listId: Int) async throws {
        addBookToListCalls.append((bookId, listId))
        if let addBookToListError {
            throw addBookToListError
        }
    }

    func removeBookFromList(listBookId: Int) async throws {
        removeBookFromListCalls.append(listBookId)
        if let removeBookFromListError {
            throw removeBookFromListError
        }
    }

    func deleteList(id: Int) async throws {}

    func getTrendingBooks(from: String, to: String, limit: Int, offset: Int) async throws -> [HardcoverTrendingBook] {
        trendingResult
    }

    func insertUserBook(bookId: Int, statusId: Int) async throws -> HardcoverUserBook {
        insertUserBookCalls.append((bookId, statusId))
        if let insertUserBookError {
            throw insertUserBookError
        }
        return insertUserBookResult
    }

    func updateUserBook(id: Int, statusId: Int?, rating: Double?, editionId: Int?) async throws -> HardcoverUserBook {
        updateUserBookCalls.append((id, statusId, rating, editionId))
        if let updateUserBookError {
            throw updateUserBookError
        }
        return updateUserBookResult
    }

    func deleteUserBook(id: Int) async throws {
        deleteUserBookCalls.append(id)
        if let deleteUserBookError {
            throw deleteUserBookError
        }
    }

    func getUserGoals() async throws -> [HardcoverGoal] {
        goalsResult
    }

    func insertGoal(metric: String, goal: Int, startDate: String, endDate: String, description: String) async throws -> Int {
        insertGoalResult
    }

    func deleteGoal(id: Int) async throws {}

    func insertUserBookRead(userBookId: Int, progressPages: Int?, progressPercent: Double?, progressSeconds: Int?) async throws -> Int {
        insertReadCalls.append((userBookId, progressPages, progressPercent, progressSeconds))
        if let insertReadError {
            throw insertReadError
        }
        return insertReadResult
    }

    func updateUserBookReview(id: Int, reviewText: String, hasSpoilers: Bool) async throws {
        updateReviewCalls.append((id, reviewText, hasSpoilers))
        if let updateReviewError {
            throw updateReviewError
        }
    }

    func insertReadingJournal(bookId: Int, event: String, entry: String?, privacySettingId: Int) async throws -> Int {
        insertJournalCalls.append((bookId, event, entry, privacySettingId))
        if let insertJournalError {
            throw insertJournalError
        }
        return 1
    }

    func getEditionsByBookId(_ bookId: Int) async throws -> [HardcoverEdition] {
        editionsByBookResult
    }
}

@MainActor
func makeInMemoryModelContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: CachedBook.self,
        CachedEdition.self,
        ListMapping.self,
        PendingMutation.self,
        configurations: configuration
    )
}

@MainActor
func resetSharedState() {
    LibraryManager.shared.resetState(clearConfiguration: true)
    MutationQueue.shared.resetState(clearConfiguration: true)
    SyncManager.shared.resetState()
    GoalManager.shared.resetState(clearConfiguration: true)
    ActivityManager.shared.resetState(clearConfiguration: true)
    ProfileManager.shared.resetState(clearConfiguration: true)
}

func makeUser(id: Int = 1, username: String = "reader") -> HardcoverUser {
    HardcoverUser(
        id: id,
        username: username,
        bio: nil,
        books_count: 10,
        followers_count: 2,
        followed_users_count: 3,
        cached_image: nil,
        created_at: nil
    )
}

func makeBookModel(id: Int = 1, title: String = "Book") -> HardcoverBook {
    HardcoverBook(
        id: id,
        title: title,
        slug: "book-\(id)",
        pages: 320,
        image: HardcoverImage(url: nil),
        cached_contributors: nil,
        contributions: nil,
        book_series: nil
    )
}

func makeUserBook(id: Int = 1, bookId: Int = 1, title: String = "Book") -> HardcoverUserBook {
    HardcoverUserBook(
        id: id,
        status_id: 2,
        rating: nil,
        created_at: nil,
        edition_id: nil,
        edition: nil,
        user_book_reads: nil,
        book: makeBookModel(id: bookId, title: title)
    )
}

func makeList(id: Int, name: String, listBooks: [HardcoverListBook]? = nil) -> HardcoverList {
    HardcoverList(
        id: id,
        name: name,
        slug: name.lowercased().replacingOccurrences(of: " ", with: "-"),
        description: nil,
        books_count: listBooks?.count,
        list_books: listBooks
    )
}

func makeListBook(id: Int?, bookId: Int, title: String = "Book") -> HardcoverListBook {
    HardcoverListBook(
        id: id,
        book_id: bookId,
        book: makeBookModel(id: bookId, title: title)
    )
}

func makeEdition(
    id: Int = 10,
    bookId: Int = 1,
    title: String = "Edition",
    bookTitle: String = "Book",
    isbn13: String? = "9780306406157"
) -> HardcoverEdition {
    HardcoverEdition(
        id: id,
        title: title,
        isbn_13: isbn13,
        isbn_10: nil,
        edition_format: "Hardcover",
        pages: 320,
        release_date: nil,
        image: HardcoverImage(url: nil),
        book: HardcoverBook(
            id: bookId,
            title: bookTitle,
            slug: "book-\(bookId)",
            pages: 320,
            image: HardcoverImage(url: nil),
            cached_contributors: nil,
            contributions: nil,
            book_series: nil
        )
    )
}
