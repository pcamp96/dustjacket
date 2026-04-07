import SwiftUI

struct SearchView: View {
    let hardcoverService: HardcoverServiceProtocol

    @State private var query = ""
    @State private var results: [HardcoverSearchResult] = []
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
                            userBookId: nil
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

        Task {
            isSearching = true
            searchError = nil
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
