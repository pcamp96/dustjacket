import SwiftUI

struct HomeView: View {
    @ObservedObject var libraryManager: LibraryManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Currently Reading
                if !currentlyReading.isEmpty {
                    sectionHeader("Currently Reading", icon: "book.fill")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(currentlyReading) { book in
                                NavigationLink(value: book) {
                                    currentlyReadingCard(book)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Recently Added
                if !recentBooks.isEmpty {
                    sectionHeader("Recently Added", icon: "clock.fill")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(recentBooks) { book in
                                NavigationLink(value: book) {
                                    BookCardView(book: book)
                                        .frame(width: 110)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Quick stats
                statsStrip
            }
            .padding(.vertical)
        }
        .navigationDestination(for: Book.self) { book in
            BookDetailView(book: book)
        }
        .task {
            if libraryManager.books.isEmpty {
                await libraryManager.fetchLibrary()
            }
        }
    }

    // MARK: - Subviews

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .padding(.horizontal)
    }

    private func currentlyReadingCard(_ book: Book) -> some View {
        HStack(spacing: 12) {
            BookCoverView(url: book.coverURL, width: 60, height: 90, cornerRadius: 6)

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.subheadline.bold())
                    .lineLimit(2)

                if !book.authorNames.isEmpty {
                    Text(book.displayAuthor)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let pages = book.pageCount {
                    Text("\(pages) pages")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .frame(width: 240)
    }

    private var statsStrip: some View {
        HStack(spacing: 0) {
            statItem(value: "\(libraryManager.books.count)", label: "Total Books")
            Divider().frame(height: 30)
            statItem(value: "\(currentlyReading.count)", label: "Reading")
            Divider().frame(height: 30)
            statItem(value: "\(readCount)", label: "Read")
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Data

    private var currentlyReading: [Book] {
        libraryManager.currentlyReading()
    }

    private var recentBooks: [Book] {
        libraryManager.recentlyAdded(limit: 10)
    }

    private var readCount: Int {
        libraryManager.books.filter { $0.statusId == 3 }.count
    }
}
