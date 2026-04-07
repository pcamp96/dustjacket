import Foundation

// MARK: - Protocol

protocol HardcoverServiceProtocol: Sendable {
    func validateToken() async throws -> HardcoverUser
    func searchBooks(query: String, page: Int, perPage: Int) async throws -> [HardcoverSearchResult]
    func getEditionByISBN(_ isbn: String) async throws -> [HardcoverEdition]
    func getUserLists() async throws -> [HardcoverList]
    func getUserBooks(statusId: Int?, limit: Int, offset: Int) async throws -> [HardcoverUserBook]
    func createList(name: String) async throws -> HardcoverList
    func addBookToList(bookId: Int, listId: Int) async throws
    func removeBookFromList(bookId: Int, listId: Int) async throws
    func deleteList(id: Int) async throws
    func getTrendingBooks(from: String, to: String, limit: Int, offset: Int) async throws -> [HardcoverTrendingBook]
    func insertUserBook(bookId: Int, statusId: Int) async throws -> HardcoverUserBook
    func updateUserBook(id: Int, statusId: Int?, rating: Double?) async throws -> HardcoverUserBook
    func deleteUserBook(id: Int) async throws
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
        let query = """
        query SearchBooks($query: String!, $page: Int!, $perPage: Int!) {
            search(query: $query, query_type: "books", per_page: $perPage, page: $page) {
                results
            }
        }
        """
        let response: HardcoverSearchResponse = try await client.execute(
            query: query,
            variables: ["query": searchQuery, "page": page, "perPage": perPage],
            responseKeyPath: "search",
            responseType: HardcoverSearchResponse.self
        )
        return response.results
    }

    // MARK: - Editions

    func getEditionByISBN(_ isbn: String) async throws -> [HardcoverEdition] {
        let query = """
        query EditionByISBN($isbn: String!) {
            editions(where: { isbn_13: { _eq: $isbn } }) {
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
                    created_at
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
                        book_id
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

    func removeBookFromList(bookId: Int, listId: Int) async throws {
        let query = """
        mutation RemoveFromList($bookId: Int!, $listId: Int!) {
            delete_list_book(
                where: { book_id: { _eq: $bookId }, list_id: { _eq: $listId } }
            ) {
                affected_rows
            }
        }
        """
        let _: HardcoverAffectedRows = try await client.execute(
            query: query,
            variables: ["bookId": bookId, "listId": listId],
            responseKeyPath: "delete_list_book",
            responseType: HardcoverAffectedRows.self
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

    func insertUserBook(bookId: Int, statusId: Int) async throws -> HardcoverUserBook {
        let query = """
        mutation InsertUserBook($bookId: Int!, $statusId: Int!) {
            insert_user_book(object: { book_id: $bookId, status_id: $statusId }) {
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
            variables: ["bookId": bookId, "statusId": statusId],
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

    func updateUserBook(id: Int, statusId: Int? = nil, rating: Double? = nil) async throws -> HardcoverUserBook {
        // Build the object fields dynamically
        var objectFields: [String] = []
        if let statusId { objectFields.append("status_id: \(statusId)") }
        if let rating { objectFields.append("rating: \(rating)") }
        let objectStr = objectFields.joined(separator: ", ")

        let query = """
        mutation UpdateUserBook($id: Int!) {
            update_user_book(id: $id, object: { \(objectStr) }) {
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
            variables: ["id": id],
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
}
