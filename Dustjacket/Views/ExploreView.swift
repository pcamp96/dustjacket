import SwiftUI

struct ExploreView: View {
    let hardcoverService: HardcoverServiceProtocol

    @State private var trendingBooks: [Book] = []
    @State private var featuredLists: [HardcoverList] = []
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Trending this week
                sectionHeader("Trending This Week", icon: "flame.fill")

                if isLoading && trendingBooks.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.vertical, 40)
                } else if trendingBooks.isEmpty {
                    Text("No trending books available.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100, maximum: 140), spacing: 12)], spacing: 16) {
                        ForEach(trendingBooks) { book in
                            NavigationLink(value: book) {
                                BookCardView(book: book)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }

                // Featured Lists
                if !featuredLists.isEmpty {
                    sectionHeader("Popular Lists", icon: "list.star")

                    VStack(spacing: 8) {
                        ForEach(featuredLists, id: \.id) { list in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(list.name)
                                    .font(.subheadline.bold())
                                HStack(spacing: 8) {
                                    if let count = list.books_count {
                                        Label("\(count) books", systemImage: "book.closed")
                                    }
                                    if let desc = list.description, !desc.isEmpty {
                                        Text(desc)
                                            .lineLimit(1)
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationDestination(for: Book.self) { book in
            BookDetailView(book: book)
        }
        .task {
            await loadContent()
        }
        .refreshable {
            await loadContent()
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .padding(.horizontal)
    }

    private func loadContent() async {
        isLoading = true

        // Load trending and featured lists in parallel
        async let trendingTask: () = loadTrending()
        async let listsTask: () = loadFeaturedLists()
        _ = await (trendingTask, listsTask)

        isLoading = false
    }

    private func loadTrending() async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let to = formatter.string(from: Date())
        let from = formatter.string(from: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date())

        do {
            let trending = try await hardcoverService.getTrendingBooks(from: from, to: to, limit: 20, offset: 0)
            trendingBooks = trending.map { Book(from: $0.book) }
        } catch {
            // Non-critical
        }
    }

    private func loadFeaturedLists() async {
        do {
            let allLists = try await hardcoverService.getUserLists()
            // Show lists with the most books as "popular"
            featuredLists = allLists
                .filter { ($0.books_count ?? 0) > 0 }
                .sorted { ($0.books_count ?? 0) > ($1.books_count ?? 0) }
                .prefix(5)
                .map { $0 }
        } catch {
            // Non-critical
        }
    }
}
