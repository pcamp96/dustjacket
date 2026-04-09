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

    func resetState(clearConfiguration: Bool = false) {
        goals = []
        isLoading = false
        errorMessage = nil

        if clearConfiguration {
            hardcoverService = nil
        }
    }

    var activeGoals: [Goal] {
        goals.filter(\.isActive)
    }

    var completedGoals: [Goal] {
        goals.filter(\.isCompleted)
    }

    func fetchGoals() async {
        guard let service = hardcoverService else { return }
        isLoading = true
        errorMessage = nil

        do {
            let hcGoals = try await service.getUserGoals()
            goals = hcGoals.map { Goal(from: $0) }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func createGoal(metric: String, target: Int, startDate: String, endDate: String, description: String) async {
        guard let service = hardcoverService else { return }

        do {
            let id = try await service.insertGoal(
                metric: metric, goal: target,
                startDate: startDate, endDate: endDate,
                description: description
            )
            // Add optimistically
            let newGoal = Goal(
                id: id, target: target, metric: metric,
                description: description, startDate: startDate,
                endDate: endDate, progress: 0,
                completedAt: nil, archived: false
            )
            goals.insert(newGoal, at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteGoal(id: Int) async {
        guard let service = hardcoverService else { return }

        // Optimistic remove
        goals.removeAll { $0.id == id }

        do {
            try await service.deleteGoal(id: id)
        } catch {
            errorMessage = error.localizedDescription
            // Refresh to restore
            await fetchGoals()
        }
    }
}
