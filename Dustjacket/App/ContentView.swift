import SwiftUI

// MARK: - Root View (Login Gate)

struct RootView: View {
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @AppStorage("hasCompletedWizard") private var hasCompletedWizard = false
    @State private var currentUser: HardcoverUser?

    let hardcoverService: HardcoverServiceProtocol

    var body: some View {
        if !isLoggedIn {
            LoginView(
                hardcoverService: hardcoverService,
                onSuccess: { user in
                    currentUser = user
                    isLoggedIn = true
                }
            )
        } else if !hasCompletedWizard {
            ListSetupWizard(
                hardcoverService: hardcoverService,
                onComplete: { hasCompletedWizard = true }
            )
        } else {
            ContentView(hardcoverService: hardcoverService, currentUser: currentUser)
                .task {
                    if currentUser == nil {
                        currentUser = try? await hardcoverService.validateToken()
                    }
                }
        }
    }
}

// MARK: - Main Content (5-Tab Layout)

struct ContentView: View {
    let hardcoverService: HardcoverServiceProtocol
    let currentUser: HardcoverUser?

    @StateObject private var libraryManager = LibraryManager.shared
    @Environment(\.modelContext) private var modelContext

    @State private var selectedTab: Tab = .home
    @State private var showAvatarMenu = false

    enum Tab: String, CaseIterable {
        case home = "Home"
        case library = "Library"
        case scanner = "Scanner"
        case explore = "Explore"
        case search = "Search"

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .library: return "books.vertical.fill"
            case .scanner: return "barcode.viewfinder"
            case .explore: return "safari.fill"
            case .search: return "magnifyingglass"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(Tab.allCases, id: \.self) { tab in
                NavigationStack {
                    tabContent(for: tab)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                avatarButton
                            }
                        }
                }
                .tabItem {
                    Label(tab.rawValue, systemImage: tab.icon)
                }
                .tag(tab)
            }
        }
        .onAppear {
            libraryManager.configure(service: hardcoverService, context: modelContext)
            SyncManager.shared.configure(service: hardcoverService, context: modelContext)
            GoalManager.shared.configure(service: hardcoverService)
            ActivityManager.shared.configure(service: hardcoverService)
        }
        .task {
            // Eagerly load list memberships so scanner can add to lists
            await libraryManager.loadListMemberships()
        }
        .sheet(isPresented: $showAvatarMenu) {
            AvatarMenuView(
                user: currentUser,
                hardcoverService: hardcoverService
            )
        }
        .preferredColorScheme(.dark)
        .tint(DustjacketTheme.accent)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private func tabContent(for tab: Tab) -> some View {
        switch tab {
        case .home:
            HomeView(libraryManager: libraryManager)
                .navigationTitle("Home")
        case .library:
            LibraryView(libraryManager: libraryManager)
                .navigationTitle("Library")
        case .scanner:
            ScannerView(hardcoverService: hardcoverService)
                .navigationTitle("Scanner")
        case .explore:
            ExploreView(hardcoverService: hardcoverService, libraryManager: libraryManager)
                .navigationTitle("Explore")
        case .search:
            SearchView(hardcoverService: hardcoverService)
                .navigationTitle("Search")
        }
    }

    // MARK: - Avatar Button

    private var avatarButton: some View {
        Button {
            showAvatarMenu = true
        } label: {
            if let imageURL = currentUser?.cached_image?.url,
               let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    avatarPlaceholder
                }
                .frame(width: 30, height: 30)
                .clipShape(Circle())
            } else {
                avatarPlaceholder
            }
        }
    }

    private var avatarPlaceholder: some View {
        Image(systemName: "person.circle.fill")
            .font(.title3)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Avatar Menu (implemented in AvatarMenuView.swift)
