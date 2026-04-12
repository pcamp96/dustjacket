import SwiftUI
import SwiftData

@main
struct DustjacketApp: App {
    let graphQLClient: GraphQLClient
    let hardcoverService: HardcoverService

    init() {
        let client = GraphQLClient(
            tokenProvider: { KeychainManager.loadToken() }
        )
        self.graphQLClient = client
        self.hardcoverService = HardcoverService(client: client)
    }

    var body: some Scene {
        WindowGroup {
            RootView(hardcoverService: hardcoverService)
        }
        .modelContainer(for: [
            CachedBook.self,
            CachedEdition.self,
            ListMapping.self,
            PendingMutation.self,
            PendingEditionImportRecord.self
        ])
    }
}
