import SwiftUI

struct AvatarMenuView: View {
    let user: HardcoverUser?
    let hardcoverService: HardcoverServiceProtocol
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @AppStorage("hasCompletedWizard") private var hasCompletedWizard = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Profile header
                profileSection

                // Navigation
                Section {
                    NavigationLink {
                        GoalsView()
                    } label: {
                        Label("Goals", systemImage: "target")
                    }

                    NavigationLink {
                        AllListsView(hardcoverService: hardcoverService)
                    } label: {
                        Label("Lists", systemImage: "list.bullet")
                    }

                    NavigationLink {
                        ActivityView()
                    } label: {
                        Label("Activity", systemImage: "bell.fill")
                    }

                    NavigationLink {
                        StatsView(user: user)
                    } label: {
                        Label("Stats", systemImage: "chart.bar.fill")
                    }

                    NavigationLink {
                        SocialView()
                    } label: {
                        Label("Social", systemImage: "person.2.fill")
                    }
                }

                Section {
                    NavigationLink {
                        SettingsView(
                            hardcoverService: hardcoverService,
                            onSignOut: {
                                KeychainManager.deleteToken()
                                isLoggedIn = false
                                hasCompletedWizard = false
                                dismiss()
                            },
                            onRerunWizard: {
                                hasCompletedWizard = false
                                dismiss()
                            }
                        )
                    } label: {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                }

                // Open in Hardcover
                if let username = user?.username,
                   let url = URL(string: "https://hardcover.app/@\(username)") {
                    Section {
                        Link(destination: url) {
                            Label("Open in Hardcover", systemImage: "safari")
                        }
                    }
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Profile Section

    private var profileSection: some View {
        Section {
            HStack(spacing: 12) {
                if let imageURL = user?.cached_image?.url,
                   let url = URL(string: imageURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        profileImagePlaceholder
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                } else {
                    profileImagePlaceholder
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(user?.username ?? "User")
                        .font(.headline)
                    HStack(spacing: 8) {
                        if let count = user?.books_count {
                            Text("\(count) books")
                        }
                        if let followers = user?.followers_count {
                            Text("· \(followers) followers")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var profileImagePlaceholder: some View {
        Image(systemName: "person.circle.fill")
            .font(.system(size: 44))
            .foregroundStyle(.secondary)
    }
}
