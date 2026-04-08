import SwiftUI

struct SearchView: View {
    let hardcoverService: HardcoverServiceProtocol

    @State private var query = ""
    @State private var results: [HardcoverSearchResult] = []
    @State private var editionResult: Edition?
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var searchError: String?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        List {
            if !hasSearched && results.isEmpty {
                ContentUnavailableView(
                    "Search Hardcover",
                    systemImage: "magnifyingglass",
                    description: Text("Search by title, author, or ISBN.")
                )
                .listRowSeparator(.hidden)
            } else if hasSearched && results.isEmpty && !isSearching {
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
                // Edition result (from ISBN search)
                if let edition = editionResult {
                    NavigationLink {
                        BookDetailView(book: Book(
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
                            editionId: nil,
                            editionPageCount: nil
                        ))
                    } label: {
                        editionResultRow(edition)
                    }
                }

                // Text search results
                ForEach(results, id: \.id) { result in
                    NavigationLink {
                        BookDetailView(book: Book(
                            id: result.id ?? 0,
                            title: result.title ?? "Unknown",
                            authorNames: result.authorNames,
                            coverURL: result.imageURL,
                            slug: nil,
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
                            editionPageCount: nil
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
        .onChange(of: query) { _, newValue in
            debounceSearch(newValue)
        }
        .onSubmit(of: .search) {
            performSearch(query)
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

    // MARK: - Debounced Search

    private func debounceSearch(_ query: String) {
        searchTask?.cancel()

        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            results = []
            hasSearched = false
            return
        }

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            performSearch(query)
        }
    }

    private func performSearch(_ searchQuery: String) {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Detect if the query looks like an ISBN
        let digitsOnly = trimmed.filter(\.isNumber)
        let looksLikeISBN = (digitsOnly.count == 10 || digitsOnly.count == 13)
            && digitsOnly.count == trimmed.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "").count

        Task {
            isSearching = true
            searchError = nil
            editionResult = nil

            if looksLikeISBN {
                // ISBN search: use edition lookup for exact match
                do {
                    let lookup = ISBNLookupService(hardcoverService: hardcoverService)
                    if let edition = try await lookup.lookup(isbn: digitsOnly) {
                        editionResult = edition
                        results = []
                        hasSearched = true
                        isSearching = false
                        return
                    }
                } catch {
                    // Fall through to text search
                }
            }

            // Text search
            do {
                results = try await hardcoverService.searchBooks(query: trimmed, page: 1, perPage: 20)
                hasSearched = true
            } catch {
                hasSearched = true
                results = []
                searchError = error.localizedDescription
            }
            isSearching = false
        }
    }
}
