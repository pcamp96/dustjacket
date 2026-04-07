import Foundation

@MainActor
final class ProfileManager: ObservableObject {
    static let shared = ProfileManager()

    @Published var profile: UserProfile?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var hardcoverService: HardcoverServiceProtocol?

    private init() {}

    func configure(service: HardcoverServiceProtocol) {
        self.hardcoverService = service
    }

    func loadProfile() async {
        guard let service = hardcoverService else { return }
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            let user = try await service.validateToken()
            profile = UserProfile(from: user)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func clearProfile() {
        profile = nil
    }
}
