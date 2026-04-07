import SwiftUI

struct LoginView: View {
    @State private var token = ""
    @State private var isValidating = false
    @State private var errorMessage: String?
    @State private var showTokenInfo = false

    var hardcoverService: HardcoverServiceProtocol
    var onSuccess: (HardcoverUser) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Logo / Header
                    VStack(spacing: 12) {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(Color.accentColor)

                        Text("Dustjacket")
                            .font(.system(.largeTitle, design: .serif, weight: .bold))

                        Text("Your Hardcover library, in your pocket")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 60)

                    // Token Input
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Connect your Hardcover account")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            SecureField("Paste your API token", text: $token)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.password)
                                .autocorrectionDisabled()
                                .autocapitalization(.none)

                            Button {
                                showTokenInfo = true
                            } label: {
                                Label("Where do I find this?", systemImage: "questionmark.circle")
                                    .font(.caption)
                            }
                        }

                        if let errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        Button {
                            Task { await validateAndSave() }
                        } label: {
                            Group {
                                if isValidating {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Sign In")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isValidating)
                    }
                    .padding(.horizontal)

                    // Privacy note
                    VStack(spacing: 4) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(.secondary)
                        Text("Your token is stored securely in the iOS Keychain and never leaves your device.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)
                }
            }
            .sheet(isPresented: $showTokenInfo) {
                TokenInfoSheet()
            }
        }
    }

    private func validateAndSave() async {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else { return }

        isValidating = true
        errorMessage = nil

        do {
            try KeychainManager.save(token: trimmedToken)
            let user = try await hardcoverService.validateToken()
            onSuccess(user)
        } catch {
            KeychainManager.deleteToken()
            errorMessage = "Could not verify your token. Please check it and try again."
        }

        isValidating = false
    }
}

// MARK: - Token Info Sheet

private struct TokenInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("How to get your API token")
                        .font(.title2.bold())

                    VStack(alignment: .leading, spacing: 16) {
                        step(number: 1, text: "Open **hardcover.app** in your browser")
                        step(number: 2, text: "Go to **Account Settings**")
                        step(number: 3, text: "Click **\"Hardcover API\"** in the sidebar")
                        step(number: 4, text: "Copy the **Bearer token** shown on that page")
                        step(number: 5, text: "Paste it back here in Dustjacket")
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Why a token?", systemImage: "info.circle")
                            .font(.subheadline.bold())
                        Text("Hardcover doesn't offer sign-in with username/password for third-party apps yet. The API token lets Dustjacket access your library securely. You can reset it anytime from your Hardcover settings.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func step(number: Int, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.bold())
                .frame(width: 24, height: 24)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(Circle())

            Text(text)
                .font(.body)
        }
    }
}
