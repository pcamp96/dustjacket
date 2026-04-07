import SwiftUI

struct ExploreView: View {
    let hardcoverService: HardcoverServiceProtocol
    @ObservedObject var libraryManager: LibraryManager

    @State private var trendingBooks: [Book] = []
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
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(trendingBooks) { book in
                                NavigationLink(value: book) {
                                    BookCardView(book: book)
                                        .frame(width: 120)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Friends reading (from library data)
                if !friendsReadingSection.isEmpty {
                    sectionHeader("Recently in Your Library", icon: "clock.fill")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(friendsReadingSection) { book in
                                NavigationLink(value: book) {
                                    BookCardView(book: book)
                                        .frame(width: 120)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationDestination(for: Book.self) { book in
            BookDetailView(book: book)
        }
        .task {
            await loadTrending()
        }
        .refreshable {
            await loadTrending()
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .padding(.horizontal)
    }

    private var friendsReadingSection: [Book] {
        libraryManager.recentlyAdded(limit: 10)
    }

    private func loadTrending() async {
        isLoading = true

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let to = formatter.string(from: Date())
        let from = formatter.string(from: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date())

        do {
            let trending = try await hardcoverService.getTrendingBooks(from: from, to: to, limit: 20, offset: 0)
            trendingBooks = trending.map { Book(from: $0.book) }
        } catch {
            // Silently fail — explore is non-critical
        }

        isLoading = false
    }
}
