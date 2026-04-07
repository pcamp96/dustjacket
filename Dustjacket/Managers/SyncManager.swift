import Foundation
import SwiftData
import Combine

@MainActor
final class SyncManager: ObservableObject {
    static let shared = SyncManager()

    @Published var hasPendingMutations = false
    @Published var pendingCount = 0

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
        refreshPendingCount()
    }

    func drainQueue() async {
        guard networkMonitor.isConnected else { return }
        await MutationQueue.shared.processQueue()
        refreshPendingCount()
    }

    func enqueueAddToList(bookId: Int, listId: Int) {
        let payload = MutationPayload(bookId: bookId, listId: listId)
        MutationQueue.shared.enqueue(mutationType: "insert_list_book", payload: payload)
        refreshPendingCount()
    }

    func enqueueRemoveFromList(bookId: Int, listId: Int) {
        let payload = MutationPayload(bookId: bookId, listId: listId)
        MutationQueue.shared.enqueue(mutationType: "delete_list_book", payload: payload)
        refreshPendingCount()
    }

    func enqueueInsertUserBook(bookId: Int, statusId: Int) {
        let payload = MutationPayload(bookId: bookId, statusId: statusId)
        MutationQueue.shared.enqueue(mutationType: "insert_user_book", payload: payload)
        refreshPendingCount()
    }

    func enqueueUpdateUserBook(userBookId: Int, statusId: Int? = nil, rating: Double? = nil) {
        let payload = MutationPayload(statusId: statusId, userBookId: userBookId, rating: rating)
        MutationQueue.shared.enqueue(mutationType: "update_user_book", payload: payload)
        refreshPendingCount()
    }

    func enqueueDeleteUserBook(userBookId: Int) {
        let payload = MutationPayload(userBookId: userBookId)
        MutationQueue.shared.enqueue(mutationType: "delete_user_book", payload: payload)
        refreshPendingCount()
    }

    private func refreshPendingCount() {
        pendingCount = MutationQueue.shared.pendingCount()
        hasPendingMutations = pendingCount > 0
    }
}
