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

    func resetState(clearConfiguration: Bool = false) {
        activities = []
        isLoading = false
        errorMessage = nil

        if clearConfiguration {
            hardcoverService = nil
        }
    }

    func fetchActivities() async {
        guard let service = hardcoverService else { return }
        isLoading = true

        // Use getUserBooks as a proxy for activity — shows recent library changes
        do {
            let userBooks = try await service.getUserBooks(statusId: nil, limit: 20, offset: 0)
            activities = userBooks.enumerated().map { index, ub in
                let statusLabel: String
                switch ub.status_id {
                case 1: statusLabel = "wants to read"
                case 2: statusLabel = "started reading"
                case 3: statusLabel = "finished"
                case 5: statusLabel = "did not finish"
                default: statusLabel = "added"
                }

                return ActivityItem(
                    id: ub.id,
                    event: statusLabel,
                    bookTitle: ub.book.title,
                    bookCoverURL: ub.book.image?.url,
                    username: nil,
                    createdAt: ub.created_at ?? ""
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

struct ActivityItem: Identifiable, Sendable {
    let id: Int
    let event: String
    let bookTitle: String?
    let bookCoverURL: String?
    let username: String?
    let createdAt: String
}
