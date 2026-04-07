import Foundation

@MainActor
final class GoalManager: ObservableObject {
    static let shared = GoalManager()

    @Published var goals: [Goal] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var hardcoverService: HardcoverServiceProtocol?

    private init() {}

    func configure(service: HardcoverServiceProtocol) {
        self.hardcoverService = service
    }

    // Goals API queries will be added when the full goal schema is validated
    // For now, this manager is a skeleton ready for Phase 7 integration
}
