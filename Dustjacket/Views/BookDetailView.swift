import SwiftUI

struct BookDetailView: View {
    @State private var book: Book
    @ObservedObject private var libraryManager = LibraryManager.shared
    @State private var showProgressSheet = false
    @State private var showReviewEditor = false
    @State private var showJournalEditor = false
    @State private var showEditionPicker = false
    @State private var reviewText: String = ""
    @State private var journalEntries: [ReadingJournal] = []

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

                // Edition selector
                HStack {
                    if book.isAudiobook {
                        if let fmt = book.editionFormat {
                            Label(fmt, systemImage: "headphones")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if let pages = book.effectivePageCount {
                        Label("\(pages) pages", systemImage: "doc.text")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        showEditionPicker = true
                    } label: {
                        Label(book.editionId != nil ? "Change Edition" : "Select Edition", systemImage: "books.vertical")
                            .font(.caption)
                    }
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
                if book.statusId == 2 {
                    VStack(spacing: 8) {
                        if let fraction = book.progressFraction {
                            ProgressView(value: fraction)
                                .tint(.orange)
                        }

                        HStack {
                            Text(book.progressLabel ?? "No progress recorded")
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
                    if book.isAudiobook {
                        if let secs = book.progressSeconds, secs > 0 {
                            let h = secs / 3600
                            let m = (secs % 3600) / 60
                            metadataRow(label: "Length", value: "\(h)h \(m)m")
                        }
                    } else if let pages = book.effectivePageCount {
                        metadataRow(label: "Pages", value: "\(pages)")
                    } else if let pages = book.pageCount {
                        metadataRow(label: "Pages", value: "\(pages)")
                    }
                }
                .padding()
                .background(.quaternary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                // Review section (only when book is in library)
                if book.userBookId != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Review")
                                .font(.subheadline.bold())
                            Spacer()
                            Button(reviewText.isEmpty ? "Write Review" : "Edit") {
                                showReviewEditor = true
                            }
                            .font(.caption)
                        }

                        if !reviewText.isEmpty {
                            Text(reviewText)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .lineLimit(5)
                        }
                    }
                    .padding()
                    .background(.quaternary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                // Reading Journal (only when book is in library)
                if book.userBookId != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Journal")
                                .font(.subheadline.bold())
                            Spacer()
                            Button("Add Entry") {
                                showJournalEditor = true
                            }
                            .font(.caption)
                        }

                        if journalEntries.isEmpty {
                            Text("No journal entries yet")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        } else {
                            ForEach(journalEntries) { entry in
                                HStack(spacing: 8) {
                                    Image(systemName: entry.eventIcon)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(entry.eventLabel)
                                            .font(.caption.bold())
                                        if let text = entry.entry, !text.isEmpty {
                                            Text(text)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                    }
                                    Spacer()
                                    if let date = entry.actionAt {
                                        Text(date.prefix(10))
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(.quaternary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

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
        .sheet(isPresented: $showEditionPicker) {
            if let service = LibraryManager.shared.hardcoverService {
                EditionPickerSheet(
                    bookId: book.id,
                    bookTitle: book.title,
                    currentEditionId: book.editionId,
                    hardcoverService: service,
                    onSelect: { edition in
                        selectEdition(edition)
                    }
                )
            }
        }
        .sheet(isPresented: $showJournalEditor) {
            JournalEditorSheet(bookTitle: book.title) { event, text in
                let entry = ReadingJournal(
                    id: Int.random(in: 100000...999999),
                    bookId: book.id,
                    event: event,
                    entry: text.isEmpty ? nil : text,
                    actionAt: ISO8601DateFormatter().string(from: Date()),
                    createdAt: nil
                )
                journalEntries.insert(entry, at: 0)
                SyncManager.shared.enqueueInsertReadingJournal(
                    bookId: book.id,
                    event: event,
                    entry: text.isEmpty ? nil : text,
                    privacySettingId: 1
                )
            }
        }
        .sheet(isPresented: $showReviewEditor) {
            ReviewEditorView(
                bookTitle: book.title,
                reviewText: reviewText,
                onSave: { text, hasSpoilers in
                    reviewText = text
                    if let userBookId = book.userBookId {
                        SyncManager.shared.enqueueUpdateUserBookReview(
                            userBookId: userBookId,
                            reviewText: text,
                            hasSpoilers: hasSpoilers
                        )
                    }
                }
            )
        }
        .sheet(isPresented: $showProgressSheet) {
            ProgressUpdateSheet(
                bookTitle: book.title,
                totalPages: book.effectivePageCount,
                isAudiobook: book.isAudiobook,
                currentPage: book.currentProgress ?? 0,
                currentPercent: book.progressPercent ?? 0,
                currentSeconds: book.progressSeconds ?? 0,
                onSave: { update in
                    updateProgress(update)
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
        book = book.with(
            statusId: .some(nil),
            rating: .some(nil),
            userBookId: .some(nil)
        )
    }

    private func updateRating(_ rating: Double) {
        guard let userBookId = book.userBookId else { return }
        SyncManager.shared.enqueueUpdateUserBook(userBookId: userBookId, rating: rating)
        libraryManager.updateBookRatingOptimistically(bookId: book.id, rating: rating)
        book = book.with(rating: rating)
    }

    private func selectEdition(_ edition: Edition) {
        book = book.with(coverURL: edition.coverURL, editionId: edition.id, editionPageCount: edition.pageCount)
        if let userBookId = book.userBookId {
            SyncManager.shared.enqueueUpdateUserBook(userBookId: userBookId, editionId: edition.id)
        }
        libraryManager.updateBookEditionOptimistically(bookId: book.id, coverURL: edition.coverURL, editionId: edition.id, editionPageCount: edition.pageCount)
    }

    private func updateProgress(_ update: ProgressUpdate) {
        // Update local state + library immediately
        switch update {
        case .pages(let pages):
            book = book.with(
                currentProgress: .some(pages),
                progressPercent: .some(nil),
                progressSeconds: .some(nil)
            )
            libraryManager.updateBookProgressOptimistically(bookId: book.id, currentProgress: pages)
        case .percent(let pct):
            book = book.with(
                currentProgress: .some(nil),
                progressPercent: .some(pct),
                progressSeconds: .some(nil)
            )
            libraryManager.updateBookProgressOptimistically(bookId: book.id, progressPercent: pct)
        case .seconds(let secs):
            book = book.with(
                currentProgress: .some(nil),
                progressPercent: .some(nil),
                progressSeconds: .some(secs)
            )
            libraryManager.updateBookProgressOptimistically(bookId: book.id, progressSeconds: secs)
        }

        // Sync to server
        guard let userBookId = book.userBookId else { return }
        switch update {
        case .pages(let pages):
            SyncManager.shared.enqueueInsertUserBookRead(
                userBookId: userBookId,
                progressPages: pages
            )
        case .percent(let pct):
            SyncManager.shared.enqueueInsertUserBookRead(
                userBookId: userBookId,
                progressPercent: pct
            )
        case .seconds(let secs):
            SyncManager.shared.enqueueInsertUserBookRead(
                userBookId: userBookId,
                progressSeconds: secs
            )
        }
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
