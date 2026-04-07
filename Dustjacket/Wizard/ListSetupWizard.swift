import SwiftUI
import SwiftData

struct ListSetupWizard: View {
    @StateObject private var manager: ListSetupManager
    @Environment(\.modelContext) private var modelContext
    var onComplete: () -> Void

    init(hardcoverService: HardcoverServiceProtocol, onComplete: @escaping () -> Void) {
        _manager = StateObject(wrappedValue: ListSetupManager(hardcoverService: hardcoverService))
        self.onComplete = onComplete
    }

    var body: some View {
        NavigationStack {
            Group {
                switch manager.step {
                case .welcome:
                    WelcomeStep(onContinue: {
                        Task { await manager.scanExistingLists() }
                    })

                case .scanning:
                    ScanningStep()

                case .matching:
                    ListMatchView(
                        matches: $manager.matchResults,
                        existingLists: manager.existingLists,
                        onAssign: { djKey, listId in
                            manager.assignList(djListKey: djKey, hardcoverListId: listId)
                        },
                        onConfirm: {
                            Task { await manager.createMissingLists(context: modelContext) }
                        }
                    )

                case .creating:
                    ListCreationView(
                        progress: manager.creationProgress,
                        total: manager.creationTotal
                    )

                case .complete:
                    CompletionStep(onDone: onComplete)
                }
            }
            .navigationTitle("Setup Your Library")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: .constant(manager.errorMessage != nil)) {
                Button("OK") { manager.errorMessage = nil }
            } message: {
                Text(manager.errorMessage ?? "")
            }
        }
    }
}

// MARK: - Welcome Step

private struct WelcomeStep: View {
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.accentColor)

                Text("Organize Your Collection")
                    .font(.system(.title2, design: .serif, weight: .bold))

                Text("Dustjacket tracks your books across 8 format-specific lists on Hardcover. We'll set those up now.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(OwnershipType.allCases) { ownership in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(ownership.rawValue)
                            .font(.subheadline.bold())
                        HStack(spacing: 8) {
                            ForEach(BookFormat.allCases) { format in
                                Label(format.rawValue, systemImage: format.icon)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.quaternary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            .padding()

            Spacer()

            Button {
                onContinue()
            } label: {
                Text("Scan My Lists")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
}

// MARK: - Scanning Step

private struct ScanningStep: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("Scanning your Hardcover lists...")
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

// MARK: - Completion Step

private struct CompletionStep: View {
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)

                Text("All Set!")
                    .font(.system(.title2, design: .serif, weight: .bold))

                Text("Your 8 Dustjacket lists are ready. Start scanning books or browse your library.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            Button {
                onDone()
            } label: {
                Text("Get Started")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
}
