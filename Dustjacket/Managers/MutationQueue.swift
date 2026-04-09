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
        purgeStaleDeleteListBookMutations()
    }

    func resetState(clearConfiguration: Bool = false) {
        isProcessing = false

        if clearConfiguration {
            hardcoverService = nil
            modelContext = nil
        }
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

    /// Remove stuck delete_list_book mutations that used the old bookId+listId format
    func purgeStaleDeleteListBookMutations() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<PendingMutation>(
            predicate: #Predicate { $0.mutationType == "delete_list_book" }
        )
        guard let stale = try? context.fetch(descriptor) else { return }
        for mutation in stale {
            if let payload = try? JSONDecoder().decode(MutationPayload.self, from: mutation.payload),
               payload.listBookId == nil {
                // Old format — no listBookId means it'll never succeed
                context.delete(mutation)
            }
        }
        try? context.save()
    }

    // MARK: - Process Queue

    func processQueue() async {
        guard !isProcessing else { return }
        guard let context = modelContext, hardcoverService != nil else { return }

        isProcessing = true
        defer { isProcessing = false }

        var didProcessAny = false

        while true {
            let pending = fetchPending(context: context)
            guard let mutation = pending.first else { break }

            mutation.status = "processing"
            try? context.save()

            do {
                try await executeMutation(mutation)
                context.delete(mutation)
                try? context.save()
                didProcessAny = true
                try await Task.sleep(for: minimumDelay)
            } catch {
                print("[MutationQueue] Error: \(mutation.mutationType) — \(error.localizedDescription)")
                mutation.retryCount += 1
                mutation.lastError = error.localizedDescription

                if mutation.retryCount >= 3 {
                    mutation.status = "failed"
                    try? context.save()
                } else {
                    mutation.status = "pending"
                    try? context.save()
                    // Skip this one and continue with the rest
                }
                try? await Task.sleep(for: minimumDelay)
                continue
            }
        }

        // After draining, refresh library to sync optimistic state with server
        if didProcessAny {
            await LibraryManager.shared.fetchLibrary(refresh: true)
        }
        SyncManager.shared.refreshStateFromQueue()
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
            guard let listBookId = payload.listBookId else {
                throw MutationError.missingFields
            }
            try await service.removeBookFromList(listBookId: listBookId)

        case "insert_user_book":
            guard let bookId = payload.bookId, let statusId = payload.statusId else {
                throw MutationError.missingFields
            }
            let _ = try await service.insertUserBook(bookId: bookId, statusId: statusId)

        case "update_user_book":
            guard let userBookId = payload.userBookId else {
                throw MutationError.missingFields
            }
            let _ = try await service.updateUserBook(id: userBookId, statusId: payload.statusId, rating: payload.rating, editionId: payload.editionId)

        case "delete_user_book":
            guard let userBookId = payload.userBookId else {
                throw MutationError.missingFields
            }
            try await service.deleteUserBook(id: userBookId)

        case "insert_user_book_read":
            guard let userBookId = payload.userBookId else {
                throw MutationError.missingFields
            }
            let _ = try await service.insertUserBookRead(
                userBookId: userBookId,
                progressPages: payload.progressPages,
                progressPercent: payload.progressPercent,
                progressSeconds: payload.progressSeconds
            )

        case "update_user_book_review":
            guard let userBookId = payload.userBookId,
                  let reviewText = payload.reviewText,
                  let hasSpoilers = payload.hasSpoilers else {
                throw MutationError.missingFields
            }
            try await service.updateUserBookReview(
                id: userBookId,
                reviewText: reviewText,
                hasSpoilers: hasSpoilers
            )

        case "insert_reading_journal":
            guard let bookId = payload.bookId,
                  let event = payload.journalEvent else {
                throw MutationError.missingFields
            }
            let _ = try await service.insertReadingJournal(
                bookId: bookId,
                event: event,
                entry: payload.journalEntry,
                privacySettingId: payload.privacySettingId ?? 1
            )

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

    func failedCount() -> Int {
        guard let context = modelContext else { return 0 }
        let descriptor = FetchDescriptor<PendingMutation>(
            predicate: #Predicate { $0.status == "failed" }
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
    var editionId: Int?
    var listBookId: Int?
    var progressPages: Int?
    var progressPercent: Double?
    var progressSeconds: Int?
    var reviewText: String?
    var hasSpoilers: Bool?
    var journalEvent: String?
    var journalEntry: String?
    var privacySettingId: Int?
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
