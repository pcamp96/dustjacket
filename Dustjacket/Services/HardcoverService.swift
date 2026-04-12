import Foundation

// MARK: - Protocol

protocol HardcoverServiceProtocol: Sendable {
    func validateToken() async throws -> HardcoverUser
    func searchBooks(query: String, page: Int, perPage: Int) async throws -> [HardcoverSearchResult]
    func getBookDetails(bookId: Int) async throws -> Book
    func getEditionByISBN(_ isbn: String) async throws -> [HardcoverEdition]
    func upsertBookByISBN(_ isbn: String) async throws -> ISBNImportSubmissionResult
    func getUserLists() async throws -> [HardcoverList]
    func getUserBooks(statusId: Int?, limit: Int, offset: Int) async throws -> [HardcoverUserBook]
    func createList(name: String) async throws -> HardcoverList
    func addBookToList(bookId: Int, listId: Int) async throws
    func removeBookFromList(listBookId: Int) async throws
    func deleteList(id: Int) async throws
    func getTrendingBooks(from: String, to: String, limit: Int, offset: Int) async throws -> [HardcoverTrendingBook]
    func insertUserBook(bookId: Int, statusId: Int, editionId: Int?) async throws -> HardcoverUserBook
    func updateUserBook(id: Int, statusId: Int?, rating: Double?, editionId: Int?) async throws -> HardcoverUserBook
    func deleteUserBook(id: Int) async throws
    func getUserGoals() async throws -> [HardcoverGoal]
    func insertGoal(metric: String, goal: Int, startDate: String, endDate: String, description: String) async throws -> Int
    func deleteGoal(id: Int) async throws
    func insertUserBookRead(userBookId: Int, progressPages: Int?, progressPercent: Double?, progressSeconds: Int?) async throws -> Int
    func updateUserBookReview(id: Int, reviewText: String, hasSpoilers: Bool) async throws
    func insertReadingJournal(bookId: Int, event: String, entry: String?, privacySettingId: Int) async throws -> Int
    func getEditionsByBookId(_ bookId: Int) async throws -> [HardcoverEdition]
}

// MARK: - Implementation

final class HardcoverService: HardcoverServiceProtocol, @unchecked Sendable {
    private let client: GraphQLClientProtocol

    init(client: GraphQLClientProtocol) {
        self.client = client
    }

    // MARK: - Auth

    func validateToken() async throws -> HardcoverUser {
        let query = """
        {
            me {
                id
                username
                bio
                books_count
                followers_count
                followed_users_count
                cached_image
                created_at
            }
        }
        """
        let users: [HardcoverUser] = try await client.execute(
            query: query,
            variables: nil,
            responseKeyPath: "me",
            responseType: [HardcoverUser].self
        )
        guard let user = users.first else {
            throw GraphQLClientError.noData
        }
        return user
    }

    // MARK: - Search

    func searchBooks(query searchQuery: String, page: Int = 1, perPage: Int = 10) async throws -> [HardcoverSearchResult] {
        // Inline the search params to avoid variable type mismatch issues
        let escapedQuery = GraphQLStringEscaper.escape(searchQuery)
        let query = """
        {
            search(query: "\(escapedQuery)", query_type: "books", per_page: \(perPage), page: \(page)) {
                results
            }
        }
        """
        let response: HardcoverSearchResponse = try await client.execute(
            query: query,
            variables: nil,
            responseKeyPath: "search",
            responseType: HardcoverSearchResponse.self
        )
        return response.results.hits?.map { HardcoverSearchResult(from: $0.document) } ?? []
    }

    // MARK: - Editions

    func getBookDetails(bookId: Int) async throws -> Book {
        async let fullBookTask = getBookById(bookId)
        async let existingUserBookTask = getUserBook(for: bookId)

        let existingUserBook = try await existingUserBookTask
        if let existingUserBook {
            return Book(from: existingUserBook)
        }

        let fullBook = try await fullBookTask
        return Book(from: fullBook)
    }

    func getEditionByISBN(_ isbn: String) async throws -> [HardcoverEdition] {
        let query = """
        query EditionByISBN($isbn: String!) {
            editions(where: { _or: [{ isbn_13: { _eq: $isbn } }, { isbn_10: { _eq: $isbn } }] }) {
                id
                title
                isbn_13
                isbn_10
                edition_format
                pages
                release_date
                image {
                    url
                }
                book {
                    id
                    title
                    slug
                    image {
                        url
                    }
                    contributions {
                        author {
                            id
                            name
                        }
                    }
                    book_series {
                        series {
                            id
                            name
                        }
                        position
                    }
                }
            }
        }
        """
        return try await client.execute(
            query: query,
            variables: ["isbn": isbn],
            responseKeyPath: "editions",
            responseType: [HardcoverEdition].self
        )
    }

    func upsertBookByISBN(_ isbn: String) async throws -> ISBNImportSubmissionResult {
        let platformId = try await getISBNPlatformId(for: isbn)
        let query = """
        mutation UpsertBookByISBN($book: CreateBookFromPlatformInput!) {
            upsert_book(book: $book) {
                id
                edition_id
                errors
                book {
                    id
                    title
                    slug
                    pages
                    image {
                        url
                    }
                    cached_contributors
                    contributions {
                        author {
                            id
                            name
                        }
                    }
                    book_series {
                        series {
                            id
                            name
                        }
                        position
                    }
                }
                edition {
                    id
                    title
                    isbn_13
                    isbn_10
                    edition_format
                    pages
                    release_date
                    image {
                        url
                    }
                    book {
                        id
                        title
                        slug
                        pages
                        image {
                            url
                        }
                        cached_contributors
                        contributions {
                            author {
                                id
                                name
                            }
                        }
                        book_series {
                            series {
                                id
                                name
                            }
                            position
                        }
                    }
                }
            }
        }
        """

        let response: HardcoverUpsertBookResponse = try await client.execute(
            query: query,
            variables: [
                "book": [
                    "external_id": isbn,
                    "platform_id": platformId
                ]
            ],
            responseKeyPath: "upsert_book",
            responseType: HardcoverUpsertBookResponse.self
        )

        return ISBNImportSubmissionResult(
            bookId: response.book?.id ?? response.id,
            editionId: response.edition_id ?? response.edition?.id,
            edition: response.edition.map(Edition.init(from:)),
            errors: response.errors ?? []
        )
    }

    // MARK: - User Books

    func getUserBooks(statusId: Int? = nil, limit: Int = 50, offset: Int = 0) async throws -> [HardcoverUserBook] {
        let whereClause: String
        if let statusId {
            whereClause = "where: { status_id: { _eq: \(statusId) } },"
        } else {
            whereClause = ""
        }

        let query = """
        {
            me {
                user_books(\(whereClause) limit: \(limit), offset: \(offset), order_by: { created_at: desc }) {
                    id
                    status_id
                    rating
                    edition_id
                    edition {
                        id
                        title
                        pages
                        edition_format
                        image {
                            url
                        }
                    }
                    created_at
                    user_book_reads(order_by: { id: desc }, limit: 1) {
                        id
                        progress
                        progress_pages
                        progress_seconds
                        started_at
                        finished_at
                    }
                    book {
                        id
                        title
                        slug
                        pages
                        image {
                            url
                        }
                        cached_contributors
                        book_series {
                            series {
                                id
                                name
                            }
                            position
                        }
                    }
                }
            }
        }
        """

        let meArray: [HardcoverMeUserBooks] = try await client.execute(
            query: query,
            variables: nil,
            responseKeyPath: "me",
            responseType: [HardcoverMeUserBooks].self
        )
        return meArray.first?.user_books ?? []
    }

    // MARK: - Lists

    func getUserLists() async throws -> [HardcoverList] {
        let query = """
        {
            me {
                lists(order_by: { created_at: asc }) {
                    id
                    name
                    slug
                    description
                    books_count
                    list_books {
                        id
                        book_id
                        book {
                            id
                            title
                            slug
                            pages
                            image { url }
                            cached_contributors
                            book_series {
                                series { id name }
                                position
                            }
                        }
                    }
                }
            }
        }
        """
        let meArray: [HardcoverMeLists] = try await client.execute(
            query: query,
            variables: nil,
            responseKeyPath: "me",
            responseType: [HardcoverMeLists].self
        )
        return meArray.first?.lists ?? []
    }

    func createList(name: String) async throws -> HardcoverList {
        let query = """
        mutation CreateList($name: String!) {
            insert_list(object: { name: $name, privacy_setting_id: 1 }) {
                id
                errors
                list {
                    id
                    name
                    slug
                    description
                    books_count
                }
            }
        }
        """
        let response: HardcoverInsertListResponse = try await client.execute(
            query: query,
            variables: ["name": name],
            responseKeyPath: "insert_list",
            responseType: HardcoverInsertListResponse.self
        )
        if let errors = response.errors, !errors.isEmpty {
            throw GraphQLClientError.graphQLErrors(errors)
        }
        guard let list = response.list else {
            throw GraphQLClientError.noData
        }
        return list
    }

    func addBookToList(bookId: Int, listId: Int) async throws {
        let query = """
        mutation AddToList($bookId: Int!, $listId: Int!) {
            insert_list_book(object: { book_id: $bookId, list_id: $listId }) {
                id
            }
        }
        """
        let _: HardcoverIDResponse = try await client.execute(
            query: query,
            variables: ["bookId": bookId, "listId": listId],
            responseKeyPath: "insert_list_book",
            responseType: HardcoverIDResponse.self
        )
    }

    func removeBookFromList(listBookId: Int) async throws {
        let query = """
        mutation RemoveFromList($id: Int!) {
            delete_list_book(id: $id) {
                id
            }
        }
        """
        let _: HardcoverIDResponse = try await client.execute(
            query: query,
            variables: ["id": listBookId],
            responseKeyPath: "delete_list_book",
            responseType: HardcoverIDResponse.self
        )
    }

    func deleteList(id: Int) async throws {
        let query = """
        mutation DeleteList($id: Int!) {
            delete_list(id: $id) {
                id
            }
        }
        """
        let _: HardcoverIDResponse = try await client.execute(
            query: query,
            variables: ["id": id],
            responseKeyPath: "delete_list",
            responseType: HardcoverIDResponse.self
        )
    }

    // MARK: - Trending

    func getTrendingBooks(from: String, to: String, limit: Int = 20, offset: Int = 0) async throws -> [HardcoverTrendingBook] {
        let query = """
        query TrendingBooks($from: date!, $to: date!, $limit: Int!, $offset: Int!) {
            books_trending(from: $from, to: $to, limit: $limit, offset: $offset) {
                book {
                    id
                    title
                    slug
                    pages
                    image {
                        url
                    }
                    cached_contributors
                    book_series {
                        series {
                            id
                            name
                        }
                        position
                    }
                }
                users_count
            }
        }
        """
        return try await client.execute(
            query: query,
            variables: ["from": from, "to": to, "limit": limit, "offset": offset],
            responseKeyPath: "books_trending",
            responseType: [HardcoverTrendingBook].self
        )
    }

    // MARK: - User Book Mutations

    func insertUserBook(bookId: Int, statusId: Int, editionId: Int? = nil) async throws -> HardcoverUserBook {
        let query = """
        mutation InsertUserBook($bookId: Int!, $statusId: Int!, $editionId: Int) {
            insert_user_book(object: { book_id: $bookId, status_id: $statusId, edition_id: $editionId }) {
                id
                error
                user_book {
                    id
                    status_id
                    rating
                    created_at
                    edition_id
                    edition {
                        id
                        title
                        pages
                        edition_format
                        image { url }
                    }
                    book {
                        id
                        title
                        slug
                        pages
                        image { url }
                        cached_contributors
                        book_series {
                            series { id name }
                            position
                        }
                    }
                }
            }
        }
        """
        let response: HardcoverUserBookMutationResponse = try await client.execute(
            query: query,
            variables: ["bookId": bookId, "statusId": statusId, "editionId": editionId ?? NSNull()],
            responseKeyPath: "insert_user_book",
            responseType: HardcoverUserBookMutationResponse.self
        )
        if let error = response.error, !error.isEmpty {
            throw GraphQLClientError.graphQLErrors([error])
        }
        guard let userBook = response.user_book else {
            throw GraphQLClientError.noData
        }
        return userBook
    }

    func updateUserBook(id: Int, statusId: Int? = nil, rating: Double? = nil, editionId: Int? = nil) async throws -> HardcoverUserBook {
        // Build object fields inline — Hardcover custom mutations accept inlined scalars
        var fields: [String] = []
        if let statusId { fields.append("status_id: \(statusId)") }
        if let rating { fields.append("rating: \(rating)") }
        if let editionId { fields.append("edition_id: \(editionId)") }
        guard !fields.isEmpty else { throw GraphQLClientError.noData }
        let objectStr = fields.joined(separator: ", ")

        // Fully inline the query — no $variables for the object fields
        let query = """
        {
            update_user_book(id: \(id), object: { \(objectStr) }) {
                id
                error
                user_book {
                    id
                    status_id
                    rating
                    created_at
                    book {
                        id
                        title
                        slug
                        pages
                        image { url }
                        cached_contributors
                        book_series {
                            series { id name }
                            position
                        }
                    }
                }
            }
        }
        """
        let response: HardcoverUserBookMutationResponse = try await client.execute(
            query: query,
            variables: nil,
            responseKeyPath: "update_user_book",
            responseType: HardcoverUserBookMutationResponse.self
        )
        if let error = response.error, !error.isEmpty {
            throw GraphQLClientError.graphQLErrors([error])
        }
        guard let userBook = response.user_book else {
            throw GraphQLClientError.noData
        }
        return userBook
    }

    func deleteUserBook(id: Int) async throws {
        let query = """
        mutation DeleteUserBook($id: Int!) {
            delete_user_book(id: $id) {
                id
            }
        }
        """
        let _: HardcoverIDResponse = try await client.execute(
            query: query,
            variables: ["id": id],
            responseKeyPath: "delete_user_book",
            responseType: HardcoverIDResponse.self
        )
    }

    // MARK: - Goals

    func getUserGoals() async throws -> [HardcoverGoal] {
        let query = """
        {
            me {
                goals(order_by: { created_at: desc }) {
                    id
                    goal
                    metric
                    description
                    start_date
                    end_date
                    progress
                    completed_at
                    archived
                }
            }
        }
        """
        let meArray: [HardcoverMeGoals] = try await client.execute(
            query: query,
            variables: nil,
            responseKeyPath: "me",
            responseType: [HardcoverMeGoals].self
        )
        return meArray.first?.goals ?? []
    }

    func insertGoal(metric: String, goal: Int, startDate: String, endDate: String, description: String) async throws -> Int {
        let escapedDesc = GraphQLStringEscaper.escape(description)
        let escapedMetric = GraphQLStringEscaper.escape(metric)
        let query = """
        mutation {
            insert_goal(object: {
                metric: "\(escapedMetric)",
                goal: \(goal),
                start_date: "\(startDate)",
                end_date: "\(endDate)",
                description: "\(escapedDesc)",
                privacy_setting_id: 1
            }) {
                id
                errors
            }
        }
        """
        let response: HardcoverMutationResponse = try await client.execute(
            query: query,
            variables: nil,
            responseKeyPath: "insert_goal",
            responseType: HardcoverMutationResponse.self
        )
        if let errors = response.errors, !errors.isEmpty {
            throw GraphQLClientError.graphQLErrors(errors)
        }
        return response.id ?? 0
    }

    func deleteGoal(id: Int) async throws {
        let query = """
        mutation DeleteGoal($id: Int!) {
            delete_goal(id: $id) {
                id
            }
        }
        """
        let _: HardcoverIDResponse = try await client.execute(
            query: query,
            variables: ["id": id],
            responseKeyPath: "delete_goal",
            responseType: HardcoverIDResponse.self
        )
    }

    // MARK: - Reading Progress

    func insertUserBookRead(userBookId: Int, progressPages: Int? = nil, progressPercent: Double? = nil, progressSeconds: Int? = nil) async throws -> Int {
        var fields: [String] = []
        var variables: [String: Any] = ["userBookId": userBookId]

        if let pages = progressPages {
            fields.append("progress_pages: $pages")
            variables["pages"] = pages
        }
        if let percent = progressPercent {
            fields.append("progress: $percent")
            variables["percent"] = percent
        }
        if let seconds = progressSeconds {
            fields.append("progress_seconds: $seconds")
            variables["seconds"] = seconds
        }

        guard !fields.isEmpty else { throw GraphQLClientError.noData }

        // Build variable declarations for the mutation signature
        var varDecls = ["$userBookId: Int!"]
        if progressPages != nil { varDecls.append("$pages: Int!") }
        if progressPercent != nil { varDecls.append("$percent: Float!") }
        if progressSeconds != nil { varDecls.append("$seconds: Int!") }

        let query = """
        mutation InsertRead(\(varDecls.joined(separator: ", "))) {
            insert_user_book_read(user_book_id: $userBookId, user_book_read: { \(fields.joined(separator: ", ")) }) {
                id
            }
        }
        """
        let response: HardcoverIDResponse = try await client.execute(
            query: query,
            variables: variables,
            responseKeyPath: "insert_user_book_read",
            responseType: HardcoverIDResponse.self
        )
        return response.id
    }

    // MARK: - Reviews

    func updateUserBookReview(id: Int, reviewText: String, hasSpoilers: Bool) async throws {
        let escapedText = GraphQLStringEscaper.escape(reviewText)

        let slateJson = "[{\\\"type\\\":\\\"paragraph\\\",\\\"children\\\":[{\\\"text\\\":\\\"\(escapedText)\\\"}]}]"

        let query = """
        {
            update_user_book(id: \(id), object: {
                review_slate: "\(slateJson)",
                review_has_spoilers: \(hasSpoilers)
            }) {
                id
                user_book { id }
            }
        }
        """
        let _: HardcoverUserBookMutationResponse = try await client.execute(
            query: query,
            variables: nil,
            responseKeyPath: "update_user_book",
            responseType: HardcoverUserBookMutationResponse.self
        )
    }

    // MARK: - Reading Journal

    func insertReadingJournal(bookId: Int, event: String, entry: String?, privacySettingId: Int = 1) async throws -> Int {
        var entryField = ""
        if let entry, !entry.isEmpty {
            let escaped = GraphQLStringEscaper.escape(entry)
            entryField = ", entry: \"\(escaped)\""
        }
        let escapedEvent = GraphQLStringEscaper.escape(event)

        let query = """
        mutation {
            insert_reading_journal(object: {
                book_id: \(bookId),
                event: "\(escapedEvent)",
                privacy_setting_id: \(privacySettingId)
                \(entryField)
            }) {
                id
                errors
            }
        }
        """
        let response: HardcoverMutationResponse = try await client.execute(
            query: query,
            variables: nil,
            responseKeyPath: "insert_reading_journal",
            responseType: HardcoverMutationResponse.self
        )
        if let errors = response.errors, !errors.isEmpty {
            throw GraphQLClientError.graphQLErrors(errors)
        }
        return response.id ?? 0
    }

    // MARK: - Editions

    func getEditionsByBookId(_ bookId: Int) async throws -> [HardcoverEdition] {
        let query = """
        query EditionsByBook($bookId: Int!) {
            editions(where: { book_id: { _eq: $bookId } }, order_by: { users_count: desc_nulls_last }) {
                id
                title
                isbn_13
                isbn_10
                edition_format
                pages
                release_date
                image {
                    url
                }
                book {
                    id
                    title
                    slug
                    image { url }
                    contributions {
                        author { id name }
                    }
                    book_series {
                        series { id name }
                        position
                    }
                }
            }
        }
        """
        return try await client.execute(
            query: query,
            variables: ["bookId": bookId],
            responseKeyPath: "editions",
            responseType: [HardcoverEdition].self
        )
    }

    private func getBookById(_ bookId: Int) async throws -> HardcoverBook {
        let query = """
        query BookById($bookId: Int!) {
            books(where: { id: { _eq: $bookId } }, limit: 1) {
                id
                title
                slug
                pages
                image {
                    url
                }
                cached_contributors
                contributions {
                    author {
                        id
                        name
                    }
                }
                book_series {
                    series {
                        id
                        name
                    }
                    position
                }
            }
        }
        """

        let books: [HardcoverBook] = try await client.execute(
            query: query,
            variables: ["bookId": bookId],
            responseKeyPath: "books",
            responseType: [HardcoverBook].self
        )

        guard let book = books.first else {
            throw GraphQLClientError.noData
        }

        return book
    }

    private func getUserBook(for bookId: Int) async throws -> HardcoverUserBook? {
        let query = """
        query UserBookByBookId($bookId: Int!) {
            me {
                user_books(where: { book_id: { _eq: $bookId } }, limit: 1, order_by: { created_at: desc }) {
                    id
                    status_id
                    rating
                    edition_id
                    edition {
                        id
                        title
                        pages
                        edition_format
                        image {
                            url
                        }
                    }
                    created_at
                    user_book_reads(order_by: { id: desc }, limit: 1) {
                        id
                        progress
                        progress_pages
                        progress_seconds
                        started_at
                        finished_at
                    }
                    book {
                        id
                        title
                        slug
                        pages
                        image {
                            url
                        }
                        cached_contributors
                        contributions {
                            author {
                                id
                                name
                            }
                        }
                        book_series {
                            series {
                                id
                                name
                            }
                            position
                        }
                    }
                }
            }
        }
        """

        let meArray: [HardcoverMeUserBooks] = try await client.execute(
            query: query,
            variables: ["bookId": bookId],
            responseKeyPath: "me",
            responseType: [HardcoverMeUserBooks].self
        )

        return meArray.first?.user_books.first
    }

    private func getPlatforms() async throws -> [HardcoverPlatform] {
        let query = """
        query Platforms {
            platforms {
                id
                name
                url
            }
        }
        """

        return try await client.execute(
            query: query,
            variables: nil,
            responseKeyPath: "platforms",
            responseType: [HardcoverPlatform].self
        )
    }

    private func getISBNPlatformId(for isbn: String) async throws -> Int {
        let platforms = try await getPlatforms()
        let loweredNames = platforms.map { ($0, $0.name.lowercased()) }
        let preferredTokens: [String]

        if isbn.count == 10 {
            preferredTokens = ["isbn 10", "isbn10"]
        } else {
            preferredTokens = ["isbn 13", "isbn13", "ean"]
        }

        if let exact = loweredNames.first(where: { pair in
            let loweredName = pair.1
            return preferredTokens.contains(where: loweredName.contains) || loweredName == "isbn"
        })?.0 {
            return exact.id
        }

        if let generic = loweredNames.first(where: { $0.1.contains("isbn") })?.0 {
            return generic.id
        }

        throw GraphQLClientError.graphQLErrors(["Hardcover ISBN import platform is unavailable"])
    }
}

private struct HardcoverUpsertBookResponse: Codable, Sendable {
    let id: Int?
    let edition_id: Int?
    let errors: [String]?
    let book: HardcoverBook?
    let edition: HardcoverEdition?
}
