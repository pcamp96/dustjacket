import Foundation

// MARK: - User

struct HardcoverUser: Codable, Sendable {
    let id: Int
    let username: String
    let bio: String?
    let books_count: Int?
    let followers_count: Int?
    let followed_users_count: Int?
    let cached_image: HardcoverImage?
    let created_at: String?
}

// MARK: - Image

struct HardcoverImage: Codable, Sendable {
    let url: String?

    // cached_image can come as JSON object with "url" or as a raw string
    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            url = try container.decodeIfPresent(String.self, forKey: .url)
        } else if let singleValue = try? decoder.singleValueContainer(),
                  let stringValue = try? singleValue.decode(String.self) {
            url = stringValue
        } else {
            url = nil
        }
    }

    init(url: String?) {
        self.url = url
    }

    private enum CodingKeys: String, CodingKey {
        case url
    }
}

// MARK: - Book

struct HardcoverBook: Codable, Sendable {
    let id: Int
    let title: String
    let slug: String?
    let pages: Int?
    let image: HardcoverImage?
    let cached_contributors: HardcoverCachedContributors?
    let contributions: [HardcoverContribution]?
    let book_series: [HardcoverBookSeries]?
}

struct HardcoverCachedContributors: Codable, Sendable {
    // This can be various JSON shapes — we extract author names
    let author: [HardcoverCachedAuthor]?

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            author = try container.decodeIfPresent([HardcoverCachedAuthor].self, forKey: .author)
        } else {
            author = nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case author
    }
}

struct HardcoverCachedAuthor: Codable, Sendable {
    let name: String?
    let id: Int?
}

struct HardcoverContribution: Codable, Sendable {
    let author: HardcoverAuthor
}

struct HardcoverAuthor: Codable, Sendable {
    let id: Int
    let name: String
}

struct HardcoverBookSeries: Codable, Sendable {
    let series: HardcoverSeries
    let position: Double?
}

struct HardcoverSeries: Codable, Sendable {
    let id: Int
    let name: String
}

// MARK: - Edition

struct HardcoverEdition: Codable, Sendable {
    let id: Int
    let title: String?
    let isbn_13: String?
    let isbn_10: String?
    let edition_format: String?
    let pages: Int?
    let release_date: String?
    let image: HardcoverImage?
    let book: HardcoverBook?
}

// MARK: - User Books

struct HardcoverUserBook: Codable, Sendable {
    let id: Int
    let status_id: Int?
    let rating: Double?
    let created_at: String?
    let book: HardcoverBook
}

struct HardcoverMeUserBooks: Codable, Sendable {
    let user_books: [HardcoverUserBook]
}

// MARK: - Lists

struct HardcoverList: Codable, Sendable {
    let id: Int
    let name: String
    let slug: String?
    let description: String?
    let books_count: Int?
    let list_books: [HardcoverListBook]?
}

struct HardcoverListBook: Codable, Sendable {
    let book_id: Int
}

struct HardcoverMeLists: Codable, Sendable {
    let lists: [HardcoverList]
}

struct HardcoverInsertListResponse: Codable, Sendable {
    let id: Int?
    let errors: [String]?
    let list: HardcoverList?
}

// MARK: - Search

struct HardcoverSearchResponse: Sendable {
    let results: [HardcoverSearchResult]
}

extension HardcoverSearchResponse: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // results is jsonb — might be an array of objects or might fail to decode as typed array
        if let typedResults = try? container.decode([HardcoverSearchResult].self, forKey: .results) {
            results = typedResults
        } else {
            results = []
        }
    }

    private enum CodingKeys: String, CodingKey {
        case results
    }
}

extension HardcoverSearchResponse: Encodable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(results, forKey: .results)
    }
}

struct HardcoverSearchResult: Codable, Sendable {
    let id: Int?
    let title: String?
    let slug: String?
    let image: String?
    let author_names: [String]?
    let cached_contributors: HardcoverCachedContributors?

    /// Extract author names from whichever field is available
    var displayAuthors: [String] {
        if let names = author_names, !names.isEmpty { return names }
        if let cached = cached_contributors?.author {
            return cached.compactMap(\.name)
        }
        return []
    }
}

// MARK: - Trending

struct HardcoverTrendingBook: Codable, Sendable {
    let book: HardcoverBook
    let users_count: Int?
}

// MARK: - User Book Mutation Response

struct HardcoverUserBookMutationResponse: Codable, Sendable {
    let id: Int?
    let error: String?
    let user_book: HardcoverUserBook?
}

// MARK: - Generic Response Types

struct HardcoverIDResponse: Codable, Sendable {
    let id: Int
}

struct HardcoverAffectedRows: Codable, Sendable {
    let affected_rows: Int
}
