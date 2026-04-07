import SwiftUI
import SwiftData

struct SettingsView: View {
    let hardcoverService: HardcoverServiceProtocol
    var onSignOut: () -> Void
    var onRerunWizard: () -> Void

    @State private var showSignOutConfirmation = false

    var body: some View {
        List {
            Section("Account") {
                HStack {
                    Text("Token Status")
                    Spacer()
                    if KeychainManager.loadToken() != nil {
                        Label("Active", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Label("Missing", systemImage: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            Section("Library") {
                Button {
                    onRerunWizard()
                } label: {
                    Label("Re-run List Setup", systemImage: "arrow.clockwise")
                }

                NavigationLink {
                    ListMappingsView()
                } label: {
                    Label("List Mappings", systemImage: "arrow.triangle.swap")
                }
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }

                Link(destination: URL(string: "https://hardcover.app")!) {
                    Label("Hardcover Website", systemImage: "safari")
                }
            }

            Section {
                Button(role: .destructive) {
                    showSignOutConfirmation = true
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog("Sign Out?", isPresented: $showSignOutConfirmation) {
            Button("Sign Out", role: .destructive) {
                onSignOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove your API token from this device.")
        }
    }
}

// MARK: - List Mappings

private struct ListMappingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var mappings: [ListMapping] = []

    var body: some View {
        List {
            if mappings.isEmpty {
                Text("No list mappings configured.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(mappings, id: \.djListKey) { mapping in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(mapping.djListKey)
                            .font(.subheadline.bold())
                        Text("→ \(mapping.hardcoverListName) (ID: \(mapping.hardcoverListId))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("List Mappings")
        .task {
            let descriptor = FetchDescriptor<ListMapping>(
                sortBy: [SortDescriptor(\.djListKey)]
            )
            mappings = (try? modelContext.fetch(descriptor)) ?? []
        }
    }
}
