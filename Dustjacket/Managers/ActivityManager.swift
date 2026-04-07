import Foundation

@MainActor
final class ActivityManager: ObservableObject {
    static let shared = ActivityManager()

    @Published var activities: [ActivityItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var hardcoverService: HardcoverServiceProtocol?

    private init() {}

    func configure(service: HardcoverServiceProtocol) {
        self.hardcoverService = service
    }

    // Activity feed queries will be implemented when we validate the activity_feed schema
}

// Lightweight activity model for display
struct ActivityItem: Identifiable, Sendable {
    let id: Int
    let event: String
    let bookTitle: String?
    let bookCoverURL: String?
    let username: String?
    let createdAt: String
}
