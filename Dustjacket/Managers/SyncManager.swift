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

    func enqueueAddToList(bookId: Int, listId: Int) async {
        let payload = MutationPayload(bookId: bookId, listId: listId)
        MutationQueue.shared.enqueue(mutationType: "insert_list_book", payload: payload)
        refreshPendingCount()
    }

    func enqueueRemoveFromList(bookId: Int, listId: Int) async {
        let payload = MutationPayload(bookId: bookId, listId: listId)
        MutationQueue.shared.enqueue(mutationType: "delete_list_book", payload: payload)
        refreshPendingCount()
    }

    private func refreshPendingCount() {
        pendingCount = MutationQueue.shared.pendingCount()
        hasPendingMutations = pendingCount > 0
    }
}
