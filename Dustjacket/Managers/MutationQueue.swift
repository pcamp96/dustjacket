import Foundation
import SwiftData

/// Processes pending mutations sequentially. Runs on @MainActor to safely
/// access ModelContext (which is not Sendable).
@MainActor
final class MutationQueue: ObservableObject {
    static let shared = MutationQueue()

    @Published var isProcessing = false

    private let minimumDelay: Duration = .milliseconds(300)
    private var hardcoverService: HardcoverServiceProtocol?
    private var modelContext: ModelContext?

    private init() {}

    func configure(service: HardcoverServiceProtocol, context: ModelContext) {
        self.hardcoverService = service
        self.modelContext = context
    }

    // MARK: - Enqueue

    func enqueue(mutationType: String, payload: MutationPayload) {
        guard let context = modelContext else { return }

        let data = (try? JSONEncoder().encode(payload)) ?? Data()
        let mutation = PendingMutation(
            mutationType: mutationType,
            payload: data
        )
        context.insert(mutation)
        try? context.save()

        Task { await processQueue() }
    }

    // MARK: - Process Queue

    func processQueue() async {
        guard !isProcessing else { return }
        guard let context = modelContext, hardcoverService != nil else { return }

        isProcessing = true
        defer { isProcessing = false }

        while true {
            let pending = fetchPending(context: context)
            guard let mutation = pending.first else { break }

            mutation.status = "processing"
            try? context.save()

            do {
                try await executeMutation(mutation)
                context.delete(mutation)
                try? context.save()
                try await Task.sleep(for: minimumDelay)
            } catch {
                print("[MutationQueue] Error executing \(mutation.mutationType): \(error.localizedDescription)")
                mutation.retryCount += 1
                mutation.lastError = error.localizedDescription
                mutation.status = mutation.retryCount >= 5 ? "failed" : "pending"
                try? context.save()

                if mutation.retryCount >= 5 {
                    continue
                }
                break
            }
        }
    }

    // MARK: - Execute

    private func executeMutation(_ mutation: PendingMutation) async throws {
        guard let service = hardcoverService else {
            throw MutationError.noService
        }

        guard let payload = try? JSONDecoder().decode(MutationPayload.self, from: mutation.payload) else {
            throw MutationError.invalidPayload
        }

        switch mutation.mutationType {
        case "insert_list_book":
            guard let bookId = payload.bookId, let listId = payload.listId else {
                throw MutationError.missingFields
            }
            try await service.addBookToList(bookId: bookId, listId: listId)

        case "delete_list_book":
            guard let bookId = payload.bookId, let listId = payload.listId else {
                throw MutationError.missingFields
            }
            try await service.removeBookFromList(bookId: bookId, listId: listId)

        case "insert_user_book":
            guard let bookId = payload.bookId, let statusId = payload.statusId else {
                throw MutationError.missingFields
            }
            let _ = try await service.insertUserBook(bookId: bookId, statusId: statusId)

        case "update_user_book":
            guard let userBookId = payload.userBookId else {
                throw MutationError.missingFields
            }
            let _ = try await service.updateUserBook(id: userBookId, statusId: payload.statusId, rating: payload.rating)

        case "delete_user_book":
            guard let userBookId = payload.userBookId else {
                throw MutationError.missingFields
            }
            try await service.deleteUserBook(id: userBookId)

        default:
            throw MutationError.unknownType(mutation.mutationType)
        }
    }

    // MARK: - Fetch Pending

    private func fetchPending(context: ModelContext) -> [PendingMutation] {
        let descriptor = FetchDescriptor<PendingMutation>(
            predicate: #Predicate { $0.status == "pending" || $0.status == "processing" },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func pendingCount() -> Int {
        guard let context = modelContext else { return 0 }
        let descriptor = FetchDescriptor<PendingMutation>(
            predicate: #Predicate { $0.status == "pending" || $0.status == "processing" }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }
}

// MARK: - Mutation Payload

struct MutationPayload: Codable, Sendable {
    var bookId: Int?
    var listId: Int?
    var statusId: Int?
    var userBookId: Int?
    var rating: Double?
}

// MARK: - Errors

enum MutationError: LocalizedError {
    case noService
    case invalidPayload
    case missingFields
    case unknownType(String)

    var errorDescription: String? {
        switch self {
        case .noService: return "Service not configured"
        case .invalidPayload: return "Invalid mutation payload"
        case .missingFields: return "Missing required fields"
        case .unknownType(let type): return "Unknown mutation type: \(type)"
        }
    }
}
