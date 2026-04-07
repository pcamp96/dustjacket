import Foundation
import Vision

@MainActor
final class ScannerManager: ObservableObject {
    @Published var scanState: ScanState = .scanning
    @Published var scannedEdition: Edition?
    @Published var foundBook: Book?
    @Published var searchResults: [HardcoverSearchResult] = []
    @Published var errorMessage: String?
    @Published var isLookingUp = false

    private let isbnLookup: ISBNLookupService
    private let hardcoverService: HardcoverServiceProtocol
    private var accumulatedText: Set<String> = []
    private var textSearchTask: Task<Void, Never>?
    private var hasAttemptedTextSearch = false
    private var failedISBNs: Set<String> = []

    init(hardcoverService: HardcoverServiceProtocol) {
        self.hardcoverService = hardcoverService
        self.isbnLookup = ISBNLookupService(hardcoverService: hardcoverService)
    }

    // MARK: - Tier 1: Barcode

    func handleBarcodeDetected(_ barcode: String) async {
        guard !isLookingUp else { return }

        let isbn = barcode.filter(\.isNumber)
        guard isbn.count == 10 || isbn.count == 13 else {
            return
        }

        textSearchTask?.cancel()
        await lookupISBN(isbn)
    }

    // MARK: - Tier 2 & 3: Text (ISBN detection → title search fallback)

    func handleTextDetected(_ text: String) async {
        guard !isLookingUp else { return }
        // Don't process more text once we've shown results
        guard scanState == .scanning else { return }

        // Tier 2: Check for ISBN in the text
        if let isbn = ISBNLookupService.extractISBN(from: text), !failedISBNs.contains(isbn) {
            textSearchTask?.cancel()
            await lookupISBN(isbn)
            return
        }

        // Tier 3: Accumulate text for title/author search (only try once)
        guard !hasAttemptedTextSearch else { return }

        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count >= 3 else { return }
        accumulatedText.insert(cleaned)

        // Debounce: wait for text to settle, then search by best candidate
        textSearchTask?.cancel()
        textSearchTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, !isLookingUp, scanState == .scanning, !hasAttemptedTextSearch else { return }
            await searchByAccumulatedText()
        }
    }

    // MARK: - ISBN Lookup

    private func lookupISBN(_ isbn: String) async {
        isLookingUp = true
        errorMessage = nil
        scanState = .lookingUp

        do {
            if let edition = try await isbnLookup.lookup(isbn: isbn) {
                scannedEdition = edition
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
                    userBookId: nil
                )
                scanState = .found
            } else {
                // Remember this ISBN failed so we don't retry it
                let cleaned = isbn.filter { $0.isNumber || $0 == "X" || $0 == "x" }
                failedISBNs.insert(cleaned)
                scanState = .scanning
                isLookingUp = false
                return
            }
        } catch {
            scanState = .scanning
            isLookingUp = false
            return
        }

        isLookingUp = false
    }

    /// Convert a search result to a Book and show detail
    func selectSearchResult(_ result: HardcoverSearchResult) {
        foundBook = Book(
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
        )
        scanState = .found
    }

    // MARK: - Title/Author Search (Tier 3)

    private func searchByAccumulatedText() async {
        hasAttemptedTextSearch = true

        // Pick the longest text fragment as the most likely title
        guard let bestCandidate = accumulatedText
            .filter({ $0.count >= 4 })
            .filter({ !$0.allSatisfy(\.isNumber) })
            .max(by: { $0.count < $1.count }) else { return }

        isLookingUp = true
        scanState = .searchingByText

        do {
            let results = try await hardcoverService.searchBooks(query: bestCandidate, page: 1, perPage: 5)
            if !results.isEmpty {
                searchResults = results
                scanState = .searchResults
            } else {
                scanState = .scanning
            }
        } catch {
            scanState = .scanning
        }

        isLookingUp = false
    }

    // MARK: - Reset

    func reset() {
        scanState = .scanning
        scannedEdition = nil
        foundBook = nil
        searchResults = []
        errorMessage = nil
        isLookingUp = false
        accumulatedText = []
        hasAttemptedTextSearch = false
        failedISBNs = []
        textSearchTask?.cancel()
    }
}

// MARK: - Scan State

enum ScanState: Equatable {
    case scanning
    case lookingUp
    case processingOCR
    case searchingByText
    case found
    case searchResults
    case notFound
}
