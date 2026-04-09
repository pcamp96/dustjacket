import Foundation

// MARK: - Protocol

protocol GraphQLClientProtocol: Sendable {
    func execute<T: Decodable>(
        query: String,
        variables: [String: Any]?,
        responseKeyPath: String,
        responseType: T.Type
    ) async throws -> T
}

// MARK: - Response Wrapper

struct GraphQLResponse<T: Decodable>: Decodable {
    let data: [String: T]?
    let errors: [GraphQLError]?

    struct GraphQLError: Decodable, CustomStringConvertible {
        let message: String
        let extensions: Extensions?

        struct Extensions: Decodable {
            let code: String?
        }

        var description: String { message }
    }
}

// MARK: - Errors

enum GraphQLClientError: LocalizedError {
    case noToken
    case httpError(statusCode: Int)
    case graphQLErrors([String])
    case noData
    case decodingFailed(Error)
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .noToken:
            return "No authentication token found. Please sign in."
        case .httpError(let code):
            return "Server returned HTTP \(code)"
        case .graphQLErrors(let messages):
            return messages.joined(separator: "\n")
        case .noData:
            return "No data returned from server"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .rateLimited:
            return "Too many requests. Please try again shortly."
        }
    }
}

// MARK: - Rate Limiter

actor TokenBucketRateLimiter {
    private let maxRequests: Int
    private let windowSeconds: TimeInterval
    private var timestamps: [Date] = []

    init(maxRequests: Int = 55, windowSeconds: TimeInterval = 60) {
        // Use 55 instead of 60 to leave headroom
        self.maxRequests = maxRequests
        self.windowSeconds = windowSeconds
    }

    func waitForPermission() async throws {
        let now = Date()
        let windowStart = now.addingTimeInterval(-windowSeconds)
        timestamps = timestamps.filter { $0 > windowStart }

        if timestamps.count >= maxRequests {
            guard let oldest = timestamps.first else { return }
            let waitTime = oldest.timeIntervalSince(windowStart)
            if waitTime > 0 {
                try await Task.sleep(for: .milliseconds(Int(waitTime * 1000) + 100))
            }
            // Prune again after waiting
            let updated = Date()
            timestamps = timestamps.filter { $0 > updated.addingTimeInterval(-windowSeconds) }
        }

        timestamps.append(Date())
    }
}

// MARK: - Client

final class GraphQLClient: GraphQLClientProtocol, @unchecked Sendable {
    private let endpoint = URL(string: "https://api.hardcover.app/v1/graphql")!
    private let session: URLSession
    private let tokenProvider: @Sendable () -> String?
    private let rateLimiter = TokenBucketRateLimiter()

    init(
        session: URLSession = .shared,
        tokenProvider: @escaping @Sendable () -> String?
    ) {
        self.session = session
        self.tokenProvider = tokenProvider
    }

    func execute<T: Decodable>(
        query: String,
        variables: [String: Any]? = nil,
        responseKeyPath: String,
        responseType: T.Type
    ) async throws -> T {
        guard let token = tokenProvider() else {
            throw GraphQLClientError.noToken
        }

        try await rateLimiter.waitForPermission()

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        var body: [String: Any] = ["query": query]
        if let variables {
            body["variables"] = variables
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            switch httpResponse.statusCode {
            case 200...299:
                break
            case 401:
                throw GraphQLClientError.noToken
            case 429:
                throw GraphQLClientError.rateLimited
            default:
                throw GraphQLClientError.httpError(statusCode: httpResponse.statusCode)
            }
        }

        // Decode using dynamic key path
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            // Check for GraphQL errors
            if let errors = json?["errors"] as? [[String: Any]] {
                let messages = errors.compactMap { $0["message"] as? String }
                if !messages.isEmpty {
                    throw GraphQLClientError.graphQLErrors(messages)
                }
            }

            // Extract the data at the specified key path
            guard let dataObject = json?["data"] as? [String: Any],
                  let targetData = dataObject[responseKeyPath] else {
                throw GraphQLClientError.noData
            }

            let targetJSON = try JSONSerialization.data(withJSONObject: targetData)
            do {
                let decoded = try JSONDecoder().decode(T.self, from: targetJSON)
                return decoded
            } catch {
                // DEBUG: Print decoding errors with context
                print("[DJ-DEBUG] Decoding FAILED for keyPath '\(responseKeyPath)' type \(T.self)")
                print("[DJ-DEBUG] Error: \(error)")
                if let rawString = String(data: targetJSON, encoding: .utf8)?.prefix(2000) {
                    print("[DJ-DEBUG] Raw JSON: \(rawString)")
                }
                throw GraphQLClientError.decodingFailed(error)
            }
        } catch let error as GraphQLClientError {
            throw error
        } catch {
            throw GraphQLClientError.decodingFailed(error)
        }
    }
}
