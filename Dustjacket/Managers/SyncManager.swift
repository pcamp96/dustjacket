import Foundation
import SwiftData
import Combine

@MainActor
final class SyncManager: ObservableObject {
    static let shared = SyncManager()

    @Published var hasPendingMutations = false
    @Published var pendingCount = 0
    @Published var failedCount = 0

    private var networkMonitor = NetworkMonitor.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Watch for network reconnection
        networkMonitor.$isConnected
            .removeDuplicates()
            .sink { [weak self] isConnected in
                if isConnected {
                    Task { @MainActor in
                        await self?.drainQueue()
                    }
                }
            }
            .store(in: &cancellables)
    }

    func configure(service: HardcoverServiceProtocol, context: ModelContext) {
        MutationQueue.shared.configure(service: service, context: context)
        refreshStateFromQueue()
    }

    func resetState() {
        hasPendingMutations = false
        pendingCount = 0
        failedCount = 0
    }

    func drainQueue() async {
        guard networkMonitor.isConnected else { return }
        await MutationQueue.shared.processQueue()
        refreshStateFromQueue()
    }

    func enqueueAddToList(bookId: Int, listId: Int) {
        let payload = MutationPayload(bookId: bookId, listId: listId)
        MutationQueue.shared.enqueue(mutationType: "insert_list_book", payload: payload)
        refreshStateFromQueue()
    }

    func enqueueRemoveFromList(listBookId: Int) {
        let payload = MutationPayload(listBookId: listBookId)
        MutationQueue.shared.enqueue(mutationType: "delete_list_book", payload: payload)
        refreshStateFromQueue()
    }

    func enqueueInsertUserBook(bookId: Int, statusId: Int) {
        let payload = MutationPayload(bookId: bookId, statusId: statusId)
        MutationQueue.shared.enqueue(mutationType: "insert_user_book", payload: payload)
        refreshStateFromQueue()
    }

    func enqueueUpdateUserBook(userBookId: Int, statusId: Int? = nil, rating: Double? = nil, editionId: Int? = nil) {
        let payload = MutationPayload(statusId: statusId, userBookId: userBookId, rating: rating, editionId: editionId)
        MutationQueue.shared.enqueue(mutationType: "update_user_book", payload: payload)
        refreshStateFromQueue()
    }

    func enqueueDeleteUserBook(userBookId: Int) {
        let payload = MutationPayload(userBookId: userBookId)
        MutationQueue.shared.enqueue(mutationType: "delete_user_book", payload: payload)
        refreshStateFromQueue()
    }

    func enqueueInsertUserBookRead(
        userBookId: Int,
        progressPages: Int? = nil,
        progressPercent: Double? = nil,
        progressSeconds: Int? = nil
    ) {
        let payload = MutationPayload(
            userBookId: userBookId,
            progressPages: progressPages,
            progressPercent: progressPercent,
            progressSeconds: progressSeconds
        )
        MutationQueue.shared.enqueue(mutationType: "insert_user_book_read", payload: payload)
        refreshStateFromQueue()
    }

    func enqueueUpdateUserBookReview(userBookId: Int, reviewText: String, hasSpoilers: Bool) {
        let payload = MutationPayload(
            userBookId: userBookId,
            reviewText: reviewText,
            hasSpoilers: hasSpoilers
        )
        MutationQueue.shared.enqueue(mutationType: "update_user_book_review", payload: payload)
        refreshStateFromQueue()
    }

    func enqueueInsertReadingJournal(bookId: Int, event: String, entry: String?, privacySettingId: Int = 1) {
        let payload = MutationPayload(
            bookId: bookId,
            journalEvent: event,
            journalEntry: entry,
            privacySettingId: privacySettingId
        )
        MutationQueue.shared.enqueue(mutationType: "insert_reading_journal", payload: payload)
        refreshStateFromQueue()
    }

    func refreshStateFromQueue() {
        pendingCount = MutationQueue.shared.pendingCount()
        failedCount = MutationQueue.shared.failedCount()
        hasPendingMutations = pendingCount > 0
    }
}
