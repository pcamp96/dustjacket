import SwiftUI

struct EditionImportSheet: View {
    @Environment(\.dismiss) private var dismiss

    let initialDraft: MissingEditionDraft
    var onComplete: (ISBNLookupOutcome) -> Void

    @State private var title: String
    @State private var authorNamesText: String
    @State private var selectedFormat: BookFormat?
    @State private var pageCountText: String
    @State private var releaseYear: String
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    init(initialDraft: MissingEditionDraft, onComplete: @escaping (ISBNLookupOutcome) -> Void) {
        self.initialDraft = initialDraft
        self.onComplete = onComplete
        _title = State(initialValue: initialDraft.title)
        _authorNamesText = State(initialValue: initialDraft.authorNamesText)
        _selectedFormat = State(initialValue: initialDraft.format)
        _pageCountText = State(initialValue: initialDraft.pageCount.map(String.init) ?? "")
        _releaseYear = State(initialValue: initialDraft.releaseYear)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("ISBN") {
                    Text(initialDraft.isbn)
                        .font(.body.monospaced())
                }

                Section {
                    Text("Dustjacket submits the ISBN to Hardcover's import pipeline. The optional notes below stay in Dustjacket so you can verify what you're trying to import while Hardcover processes it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Reference Notes") {
                    TextField("Title", text: $title)
                    TextField("Author", text: $authorNamesText)

                    Picker("Format", selection: $selectedFormat) {
                        Text("Unknown").tag(BookFormat?.none)
                        ForEach(BookFormat.allCases) { format in
                            Text(format.rawValue).tag(BookFormat?.some(format))
                        }
                    }

                    TextField("Page Count", text: $pageCountText)
                        .keyboardType(.numberPad)

                    TextField("Release Year", text: $releaseYear)
                        .keyboardType(.numberPad)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Import Edition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("Import")
                        }
                    }
                    .disabled(isSubmitting)
                }
            }
        }
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil

        let pageCount = Int(pageCountText.trimmingCharacters(in: .whitespacesAndNewlines))
        let draft = MissingEditionDraft(
            isbn: initialDraft.isbn,
            source: initialDraft.source,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            authorNamesText: authorNamesText.trimmingCharacters(in: .whitespacesAndNewlines),
            format: selectedFormat,
            pageCount: pageCount,
            releaseYear: releaseYear.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        do {
            let outcome = try await EditionImportManager.shared.submitImport(draft)
            onComplete(outcome)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }
}
