import SwiftUI

struct BookDetailView: View {
    @State private var book: Book
    @ObservedObject private var libraryManager = LibraryManager.shared

    init(book: Book) {
        _book = State(initialValue: book)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Cover
                BookCoverView(url: book.coverURL, width: 180, height: 270, cornerRadius: 12)
                    .shadow(radius: 8, y: 4)

                // Title & Author
                VStack(spacing: 6) {
                    Text(book.title)
                        .font(.system(.title2, design: .serif, weight: .bold))
                        .multilineTextAlignment(.center)

                    if !book.authorNames.isEmpty {
                        Text(book.displayAuthor)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)

                // Series badge
                if let seriesName = book.seriesName {
                    HStack(spacing: 4) {
                        Image(systemName: "books.vertical")
                            .font(.caption)
                        Text(seriesName)
                        if let position = book.seriesPosition {
                            Text("#\(position, specifier: "%.0f")")
                                .fontWeight(.bold)
                        }
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.quaternary)
                    .clipShape(Capsule())
                }

                // Reading Status Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reading Status")
                        .font(.subheadline.bold())
                        .padding(.horizontal)

                    StatusPickerView(
                        currentStatusId: book.statusId,
                        userBookId: book.userBookId,
                        bookId: book.id,
                        onStatusChanged: { newStatusId in
                            changeStatus(to: newStatusId)
                        },
                        onRemove: {
                            removeFromLibrary()
                        }
                    )
                    .padding(.horizontal)
                }

                // Format Collection (Owned / Want per format)
                FormatCollectionView(bookId: book.id, book: book, libraryManager: libraryManager)
                    .padding()
                    .background(.quaternary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                // Metadata
                VStack(spacing: 12) {
                    if let pages = book.pageCount {
                        metadataRow(label: "Pages", value: "\(pages)")
                    }

                    if let rating = book.rating, rating > 0 {
                        metadataRow(label: "Your Rating", value: String(repeating: "★", count: Int(rating)))
                    }
                }
                .padding()
                .background(.quaternary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                // Hardcover link
                if let url = book.hardcoverURL {
                    Link(destination: url) {
                        Label("View on Hardcover", systemImage: "safari")
                            .font(.subheadline)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Actions

    private func changeStatus(to statusId: Int) {
        if let userBookId = book.userBookId {
            // Update existing user_book
            SyncManager.shared.enqueueUpdateUserBook(userBookId: userBookId, statusId: statusId)
        } else {
            // Insert new user_book
            SyncManager.shared.enqueueInsertUserBook(bookId: book.id, statusId: statusId)
        }

        // Optimistic update
        libraryManager.updateBookStatusOptimistically(bookId: book.id, statusId: statusId)
        book = Book(
            id: book.id, title: book.title, authorNames: book.authorNames,
            coverURL: book.coverURL, slug: book.slug, pageCount: book.pageCount,
            isbn13: book.isbn13, seriesID: book.seriesID, seriesName: book.seriesName,
            seriesPosition: book.seriesPosition, statusId: statusId,
            rating: book.rating, userBookId: book.userBookId
        )
    }

    private func removeFromLibrary() {
        guard let userBookId = book.userBookId else { return }
        SyncManager.shared.enqueueDeleteUserBook(userBookId: userBookId)
        libraryManager.removeBookOptimistically(id: book.id)
        book = Book(
            id: book.id, title: book.title, authorNames: book.authorNames,
            coverURL: book.coverURL, slug: book.slug, pageCount: book.pageCount,
            isbn13: book.isbn13, seriesID: book.seriesID, seriesName: book.seriesName,
            seriesPosition: book.seriesPosition, statusId: nil,
            rating: nil, userBookId: nil
        )
    }

    // MARK: - Helpers

    private func metadataRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}
