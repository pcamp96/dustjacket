import Foundation
import SwiftData

@MainActor
enum SessionCleanup {
    static func clearListMappings(context: ModelContext) {
        deleteAll(ListMapping.self, from: context)
        try? context.save()
        LibraryManager.shared.clearListMembershipState()
    }

    static func signOut(context: ModelContext) {
        deleteAll(CachedBook.self, from: context)
        deleteAll(CachedEdition.self, from: context)
        deleteAll(ListMapping.self, from: context)
        deleteAll(PendingMutation.self, from: context)
        try? context.save()

        LibraryManager.shared.resetState(clearConfiguration: true)
        MutationQueue.shared.resetState(clearConfiguration: true)
        SyncManager.shared.resetState()
        GoalManager.shared.resetState(clearConfiguration: true)
        ActivityManager.shared.resetState(clearConfiguration: true)
        ProfileManager.shared.resetState(clearConfiguration: true)
    }

    private static func deleteAll<Model: PersistentModel>(_ model: Model.Type, from context: ModelContext) {
        let descriptor = FetchDescriptor<Model>()
        guard let models = try? context.fetch(descriptor) else { return }
        for model in models {
            context.delete(model)
        }
    }
}
