import SwiftUI

struct ScanResultView: View {
    let edition: Edition
    let hardcoverService: HardcoverServiceProtocol
    var onDismiss: () -> Void

    @State private var selectedDJList: DJList?
    @State private var isSaving = false
    @State private var saved = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Back button
                HStack {
                    Button {
                        onDismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Scan")
                        }
                        .font(.body)
                    }
                    Spacer()
                }
                .padding(.horizontal)

                // Book cover
                BookCoverView(
                    url: edition.coverURL,
                    width: 160,
                    height: 240,
                    cornerRadius: 10
                )
                .shadow(radius: 8, y: 4)

                // Book info
                VStack(spacing: 6) {
                    Text(edition.bookTitle ?? edition.title ?? "Unknown Title")
                        .font(.system(.title3, design: .serif, weight: .bold))
                        .multilineTextAlignment(.center)

                    if !edition.authorNames.isEmpty {
                        Text(edition.authorNames.joined(separator: ", "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                // Edition details
                HStack(spacing: 16) {
                    if let format = edition.format {
                        Label(format.rawValue, systemImage: format.icon)
                            .font(.caption)
                    }
                    if let isbn = edition.isbn13 {
                        Label(isbn, systemImage: "barcode")
                            .font(.caption)
                    }
                    if let pages = edition.pageCount {
                        Label("\(pages) pages", systemImage: "doc.text")
                            .font(.caption)
                    }
                }
                .foregroundStyle(.secondary)

                // Series badge
                if let seriesName = edition.seriesName {
                    HStack(spacing: 4) {
                        Image(systemName: "books.vertical")
                        Text(seriesName)
                        if let pos = edition.seriesPosition {
                            Text("#\(pos, specifier: "%.0f")")
                                .fontWeight(.bold)
                        }
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.quaternary)
                    .clipShape(Capsule())
                }

                Divider()
                    .padding(.horizontal)

                // List selector
                VStack(alignment: .leading, spacing: 12) {
                    Text("Add to list")
                        .font(.headline)
                        .padding(.horizontal)

                    ForEach(DJList.all) { djList in
                        Button {
                            selectedDJList = djList
                        } label: {
                            HStack {
                                Image(systemName: djList.icon)
                                    .frame(width: 24)
                                Text(djList.displayName)
                                Spacer()
                                if selectedDJList == djList {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(selectedDJList == djList ? Color.accentColor.opacity(0.1) : .clear)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Action buttons
                HStack(spacing: 16) {
                    Button("Cancel") {
                        onDismiss()
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Task { await saveToList() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else if saved {
                            Label("Added!", systemImage: "checkmark")
                        } else {
                            Text("Add to Library")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedDJList == nil || isSaving || saved)
                }
                .padding()

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(.vertical)
        }
    }

    private func saveToList() async {
        guard let djList = selectedDJList else { return }

        isSaving = true
        errorMessage = nil

        guard LibraryManager.shared.hardcoverListId(for: djList.key) != nil else {
            errorMessage = "List not set up. Please re-run the setup wizard."
            isSaving = false
            return
        }

        let book = Book(
            id: edition.bookId,
            title: edition.bookTitle ?? edition.title ?? "Unknown",
            authorNames: edition.authorNames,
            coverURL: edition.coverURL,
            slug: edition.bookSlug,
            pageCount: edition.pageCount,
            isbn13: edition.isbn13,
            seriesID: edition.seriesID,
            seriesName: edition.seriesName,
            seriesPosition: edition.seriesPosition,
            statusId: nil,
            rating: nil,
            userBookId: nil,
            currentProgress: nil,
            progressPercent: nil,
            progressSeconds: nil,
            editionId: edition.id != 0 ? edition.id : nil,
            editionPageCount: edition.pageCount,
            editionFormat: edition.format?.rawValue,
            lastReadAt: nil
        )

        LibraryManager.shared.toggleBookOnDJList(
            bookId: edition.bookId,
            ownership: djList.ownership,
            format: djList.format,
            book: book
        )

        saved = true

        // Auto-dismiss after a moment
        try? await Task.sleep(for: .seconds(1.5))
        onDismiss()

        isSaving = false
    }
}
