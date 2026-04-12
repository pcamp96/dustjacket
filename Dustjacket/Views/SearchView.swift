import SwiftUI

struct SearchView: View {
    let hardcoverService: HardcoverServiceProtocol

    @State private var query = ""
    @State private var results: [HardcoverSearchResult] = []
    @State private var editionResult: Edition?
    @State private var missingImportDraft: MissingEditionDraft?
    @State private var pendingImport: PendingEditionImportStatus?
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var searchError: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var importSheetDraft: MissingEditionDraft?

    var body: some View {
        List {
            if !hasSearched && results.isEmpty && !hasISBNLookupState {
                ContentUnavailableView(
                    "Search Hardcover",
                    systemImage: "magnifyingglass",
                    description: Text("Search by title, author, or ISBN.")
                )
                .listRowSeparator(.hidden)
            } else if hasSearched && results.isEmpty && !isSearching && !hasISBNLookupState {
                VStack(spacing: 8) {
                    ContentUnavailableView.search(text: query)
                    if let searchError {
                        Text(searchError)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }
                }
                .listRowSeparator(.hidden)
            } else {
                if let edition = editionResult {
                    NavigationLink {
                        BookDetailView(book: Book(from: edition))
                    } label: {
                        editionResultRow(edition)
                    }
                }

                if let pendingImport {
                    pendingImportRow(pendingImport)
                }

                if let missingImportDraft {
                    missingImportRow(missingImportDraft)
                }

                // Text search results
                ForEach(results, id: \.id) { result in
                    NavigationLink {
                        BookDetailView(book: Book(
                            id: result.id ?? 0,
                            title: result.title ?? "Unknown",
                            authorNames: result.authorNames,
                            coverURL: result.imageURL,
                            slug: result.slug,
                            pageCount: nil,
                            isbn13: nil,
                            seriesID: nil,
                            seriesName: nil,
                            seriesPosition: nil,
                            statusId: nil,
                            rating: nil,
                            userBookId: nil,
                            currentProgress: nil,
                            progressPercent: nil,
                            progressSeconds: nil,
                            editionId: nil,
                            editionPageCount: nil,
                            editionFormat: nil,
                            lastReadAt: nil
                        ))
                    } label: {
                        searchResultRow(result)
                    }
                }
            }

            if isSearching {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .searchable(text: $query, prompt: "Books, authors, ISBN...")
        .sheet(item: $importSheetDraft) { draft in
            EditionImportSheet(initialDraft: draft) { outcome in
                applyISBNLookupOutcome(outcome)
            }
        }
        .onChange(of: query) { _, newValue in
            startSearch(newValue, debounced: true)
        }
        .onSubmit(of: .search) {
            startSearch(query, debounced: false)
        }
    }

    private func searchResultRow(_ result: HardcoverSearchResult) -> some View {
        HStack(spacing: 12) {
            if let imageURL = result.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                }
                .frame(width: 44, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.quaternary)
                    .frame(width: 44, height: 66)
                    .overlay {
                        Image(systemName: "book.closed.fill")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(result.title ?? "Unknown Title")
                    .font(.subheadline.bold())
                    .lineLimit(2)

                if !result.authorNames.isEmpty {
                    Text(result.authorNames.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func editionResultRow(_ edition: Edition) -> some View {
        HStack(spacing: 12) {
            if let coverURL = edition.coverURL, let url = URL(string: coverURL) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 4).fill(.quaternary)
                }
                .frame(width: 44, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.quaternary)
                    .frame(width: 44, height: 66)
                    .overlay {
                        Image(systemName: "book.closed.fill")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(edition.bookTitle ?? edition.title ?? "Unknown")
                    .font(.subheadline.bold())
                    .lineLimit(2)

                if !edition.authorNames.isEmpty {
                    Text(edition.authorNames.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    if let format = edition.format {
                        Label(format.rawValue, systemImage: format.icon)
                    }
                    if let isbn = edition.isbn13 {
                        Text(isbn)
                    }
                    if let pages = edition.pageCount {
                        Text("\(pages)p")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private func missingImportRow(_ draft: MissingEditionDraft) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("ISBN not on Hardcover yet", systemImage: "square.and.arrow.down")
                .font(.headline)

            Text("Import this edition by ISBN and keep the flow edition-linked before you add it to your library.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(draft.isbn)
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)

            Button("Import Missing Edition") {
                importSheetDraft = draft
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 8)
        .listRowSeparator(.hidden)
    }

    private func pendingImportRow(_ pending: PendingEditionImportStatus) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Edition import pending", systemImage: "clock.arrow.circlepath")
                .font(.headline)

            Text("Hardcover is still processing this ISBN. Dustjacket will keep checking for the edition.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(pending.isbn)
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)

            if !pending.title.isEmpty || !pending.authorNamesText.isEmpty {
                Text([pending.title, pending.authorNamesText]
                    .filter { !$0.isEmpty }
                    .joined(separator: " • "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let lastError = pending.lastError, !lastError.isEmpty {
                Text(lastError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button("Check Again") {
                Task {
                    guard let outcome = await EditionImportManager.shared.checkPendingImport(pending.isbn) else {
                        return
                    }
                    applyISBNLookupOutcome(outcome)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 8)
        .listRowSeparator(.hidden)
    }

    // MARK: - Debounced Search

    private func startSearch(_ query: String, debounced: Bool) {
        searchTask?.cancel()

        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            results = []
            editionResult = nil
            missingImportDraft = nil
            pendingImport = nil
            searchError = nil
            hasSearched = false
            isSearching = false
            return
        }

        searchTask = Task {
            if debounced {
                try? await Task.sleep(for: .milliseconds(300))
            }
            guard !Task.isCancelled else { return }
            await performSearch(query)
        }
    }

    @MainActor
    private func performSearch(_ searchQuery: String) async {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Detect if the query looks like an ISBN
        let digitsOnly = trimmed.filter(\.isNumber)
        let looksLikeISBN = (digitsOnly.count == 10 || digitsOnly.count == 13)
            && digitsOnly.count == trimmed.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "").count

        isSearching = true
        searchError = nil
        editionResult = nil
        missingImportDraft = nil
        pendingImport = nil

        if looksLikeISBN {
            do {
                let outcome = try await EditionImportManager.shared.lookupISBN(digitsOnly, source: .search)
                guard !Task.isCancelled, isCurrentQuery(trimmed) else { return }

                applyISBNLookupOutcome(outcome)
                results = []
                hasSearched = true
                isSearching = false
                return
            } catch {
                guard !Task.isCancelled, isCurrentQuery(trimmed) else { return }
                searchError = error.localizedDescription
                hasSearched = true
                results = []
                isSearching = false
                return
            }
        }

        do {
            let foundResults = try await hardcoverService.searchBooks(query: trimmed, page: 1, perPage: 20)
            guard !Task.isCancelled, isCurrentQuery(trimmed) else { return }
            results = foundResults
            hasSearched = true
        } catch {
            guard !Task.isCancelled, isCurrentQuery(trimmed) else { return }
            hasSearched = true
            results = []
            searchError = error.localizedDescription
        }
        isSearching = false
    }

    private func applyISBNLookupOutcome(_ outcome: ISBNLookupOutcome) {
        searchError = nil

        switch outcome {
        case .found(let edition):
            editionResult = edition
            missingImportDraft = nil
            pendingImport = nil

        case .missing(let draft):
            editionResult = nil
            missingImportDraft = draft
            pendingImport = nil

        case .pending(let pending):
            editionResult = nil
            missingImportDraft = nil
            pendingImport = pending
        }
    }

    private func isCurrentQuery(_ expected: String) -> Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines) == expected
    }

    private var hasISBNLookupState: Bool {
        editionResult != nil || missingImportDraft != nil || pendingImport != nil
    }
}
