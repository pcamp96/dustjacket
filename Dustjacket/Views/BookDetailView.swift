import SwiftUI

struct BookDetailView: View {
    @State private var book: Book
    @ObservedObject private var libraryManager = LibraryManager.shared
    @State private var showProgressSheet = false

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

                // Star Rating (only when book is in library)
                if book.userBookId != nil {
                    VStack(spacing: 4) {
                        Text("Your Rating")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        StarRatingView(rating: book.rating ?? 0) { newRating in
                            updateRating(newRating)
                        }
                    }
                }

                // Reading Progress (only when currently reading)
                if book.statusId == 2, let pages = book.pageCount, pages > 0 {
                    VStack(spacing: 8) {
                        ProgressView(value: Double(book.currentProgress ?? 0), total: Double(pages))
                            .tint(.orange)

                        HStack {
                            Text("\(book.currentProgress ?? 0) of \(pages) pages")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Update") {
                                showProgressSheet = true
                            }
                            .font(.caption)
                        }
                    }
                    .padding()
                    .background(.quaternary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
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
        .sheet(isPresented: $showProgressSheet) {
            ProgressUpdateSheet(
                bookTitle: book.title,
                totalPages: book.pageCount,
                currentPage: book.currentProgress ?? 0,
                onSave: { pages in
                    updateProgress(pages: pages)
                },
                onMarkFinished: {
                    changeStatus(to: 3) // Mark as Read
                }
            )
        }
    }

    // MARK: - Actions

    private func changeStatus(to statusId: Int) {
        if let userBookId = book.userBookId {
            SyncManager.shared.enqueueUpdateUserBook(userBookId: userBookId, statusId: statusId)
        } else {
            SyncManager.shared.enqueueInsertUserBook(bookId: book.id, statusId: statusId)
        }

        libraryManager.updateBookStatusOptimistically(bookId: book.id, statusId: statusId)
        book = book.with(statusId: statusId)
    }

    private func removeFromLibrary() {
        guard let userBookId = book.userBookId else { return }
        SyncManager.shared.enqueueDeleteUserBook(userBookId: userBookId)
        libraryManager.removeBookOptimistically(id: book.id)
        book = book.with(statusId: nil, rating: nil, userBookId: nil)
    }

    private func updateRating(_ rating: Double) {
        guard let userBookId = book.userBookId else { return }
        SyncManager.shared.enqueueUpdateUserBook(userBookId: userBookId, rating: rating)
        libraryManager.updateBookRatingOptimistically(bookId: book.id, rating: rating)
        book = book.with(rating: rating)
    }

    private func updateProgress(pages: Int) {
        // TODO: Wire to insert_user_book_read mutation when Phase 2 API is implemented
        book = book.with(currentProgress: pages)
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
