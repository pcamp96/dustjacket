import SwiftUI

struct SocialView: View {
    @ObservedObject private var profileManager = ProfileManager.shared

    var body: some View {
        List {
            if let profile = profileManager.profile {
                Section {
                    HStack {
                        Label("Followers", systemImage: "person.2.fill")
                        Spacer()
                        Text("\(profile.followersCount)")
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Following", systemImage: "person.badge.plus")
                        Spacer()
                        Text("\(profile.followingCount)")
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Books", systemImage: "books.vertical.fill")
                        Spacer()
                        Text("\(profile.booksCount)")
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                }

                if let url = profile.hardcoverURL {
                    Section {
                        Link(destination: url) {
                            Label("View Profile on Hardcover", systemImage: "safari")
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "Social",
                    systemImage: "person.2.fill",
                    description: Text("Loading your social info...")
                )
            }
        }
        .navigationTitle("Social")
        .task {
            if profileManager.profile == nil {
                await profileManager.loadProfile()
            }
        }
    }
}
