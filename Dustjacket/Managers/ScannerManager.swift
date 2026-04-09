import Foundation

@MainActor
final class ScannerManager: ObservableObject {
    @Published var scanState: ScanState = .scanning
    @Published var foundBook: Book?
    @Published var lastScannedISBN: String?
    @Published var errorMessage: String?
    @Published var isLookingUp = false
    @Published private(set) var scannerSessionID = UUID()

    private let isbnLookup: ISBNLookupService
    private let duplicateCooldown: TimeInterval = 1.5
    private var recentAttempts: [String: Date] = [:]
    private var lookupTask: Task<Void, Never>?
    private var activeLookupID = UUID()

    init(hardcoverService: HardcoverServiceProtocol) {
        self.isbnLookup = ISBNLookupService(hardcoverService: hardcoverService)
    }

    deinit {
        lookupTask?.cancel()
    }

    // MARK: - Tier 1: Barcode

    func handleBarcodeDetected(_ barcode: String) {
        guard let isbn = ISBNLookupService.normalizedISBN(from: barcode) else {
            return
        }

        submitLookup(for: isbn)
    }

    // MARK: - Tier 2: ISBN in text

    func handleTextDetected(_ text: String) {
        guard ISBNLookupService.likelyContainsISBN(text) else { return }
        guard let isbn = ISBNLookupService.extractISBN(from: text) else {
            return
        }

        submitLookup(for: isbn)
    }

    // MARK: - ISBN Lookup

    private func submitLookup(for isbn: String) {
        guard scanState == .scanning, !isLookingUp else { return }
        guard shouldAttemptLookup(for: isbn) else { return }

        lookupISBN(isbn)
    }

    private func lookupISBN(_ isbn: String) {
        lookupTask?.cancel()

        let lookupID = UUID()
        activeLookupID = lookupID
        isLookingUp = true
        errorMessage = nil
        scanState = .lookingUp
        lastScannedISBN = isbn

        lookupTask = Task { [isbnLookup] in
            do {
                let edition = try await isbnLookup.lookup(isbn: isbn)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    finishLookup(lookupID: lookupID, isbn: isbn, edition: edition)
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    finishLookupError(lookupID: lookupID, error: error)
                }
            }
        }
    }

    // MARK: - Reset

    func resumeScanning() {
        lookupTask?.cancel()
        activeLookupID = UUID()
        scanState = .scanning
        foundBook = nil
        errorMessage = nil
        isLookingUp = false
        scannerSessionID = UUID()
    }

    func reset() {
        recentAttempts = [:]
        lastScannedISBN = nil
        resumeScanning()
    }

    private func finishLookup(lookupID: UUID, isbn: String, edition: Edition?) {
        guard lookupID == activeLookupID else { return }

        isLookingUp = false

        guard let edition else {
            foundBook = nil
            scanState = .notFound
            return
        }

        foundBook = Book(
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
        scanState = .found
    }

    private func finishLookupError(lookupID: UUID, error: Error) {
        guard lookupID == activeLookupID else { return }

        isLookingUp = false
        scanState = .scanning
        errorMessage = "Couldn’t look up this ISBN right now. Try again."
        scannerSessionID = UUID()
    }

    private func shouldAttemptLookup(for isbn: String) -> Bool {
        pruneRecentAttempts()

        if let lastAttempt = recentAttempts[isbn],
           Date().timeIntervalSince(lastAttempt) < duplicateCooldown {
            return false
        }

        recentAttempts[isbn] = Date()
        return true
    }

    private func pruneRecentAttempts() {
        let cutoff = Date().addingTimeInterval(-duplicateCooldown)
        recentAttempts = recentAttempts.filter { $0.value >= cutoff }
    }
}

// MARK: - Scan State

enum ScanState: Equatable {
    case scanning
    case lookingUp
    case found
    case notFound
}
