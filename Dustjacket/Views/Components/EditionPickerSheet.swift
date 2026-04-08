import SwiftUI

struct EditionPickerSheet: View {
    let bookId: Int
    let bookTitle: String
    let currentEditionId: Int?
    let hardcoverService: HardcoverServiceProtocol
    var onSelect: (Edition) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var editions: [Edition] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading editions...")
                } else if editions.isEmpty {
                    ContentUnavailableView(
                        "No Editions Found",
                        systemImage: "book.closed",
                        description: Text("No editions available for this book.")
                    )
                } else {
                    List {
                        ForEach(groupedFormats, id: \.0) { format, editionsInGroup in
                            Section(format) {
                                ForEach(editionsInGroup) { edition in
                                    editionRow(edition)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Select Edition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task {
            await loadEditions()
        }
    }

    private func editionRow(_ edition: Edition) -> some View {
        Button {
            onSelect(edition)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                // Cover
                if let coverURL = edition.coverURL, let url = URL(string: coverURL) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 4).fill(.quaternary)
                    }
                    .frame(width: 36, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(edition.title ?? edition.bookTitle ?? bookTitle)
                        .font(.subheadline)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        if let pages = edition.pageCount {
                            Text("\(pages) pages")
                        }
                        if let isbn = edition.isbn13 ?? edition.isbn10 {
                            Text(isbn)
                        }
                        if let year = edition.releaseDate?.prefix(4) {
                            Text(String(year))
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }

                Spacer()

                if edition.id == currentEditionId {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var groupedFormats: [(String, [Edition])] {
        let grouped = Dictionary(grouping: editions) { edition -> String in
            edition.format?.rawValue ?? "Other"
        }
        let order = ["Hardback", "Paperback", "eBook", "Audiobook", "Other"]
        return order.compactMap { key in
            guard let editionsInGroup = grouped[key], !editionsInGroup.isEmpty else { return nil }
            return (key, editionsInGroup)
        }
    }

    private func loadEditions() async {
        do {
            let hcEditions = try await hardcoverService.getEditionsByBookId(bookId)
            editions = hcEditions.map { Edition(from: $0) }
        } catch {
            // Show empty state
        }
        isLoading = false
    }
}
