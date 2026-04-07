import Foundation
import Vision

@MainActor
final class ScannerManager: ObservableObject {
    @Published var scanState: ScanState = .scanning
    @Published var scannedEdition: Edition?
    @Published var searchResults: [HardcoverSearchResult] = []
    @Published var errorMessage: String?
    @Published var isLookingUp = false

    private let isbnLookup: ISBNLookupService
    private let hardcoverService: HardcoverServiceProtocol
    private var accumulatedText: Set<String> = []
    private var textSearchTask: Task<Void, Never>?

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

        // Tier 2: Check for ISBN in the text
        if let isbn = ISBNLookupService.extractISBN(from: text) {
            textSearchTask?.cancel()
            await lookupISBN(isbn)
            return
        }

        // Tier 3: Accumulate text for title/author search
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count >= 3 else { return }
        accumulatedText.insert(cleaned)

        // Debounce: wait for text to settle, then search by best candidate
        textSearchTask?.cancel()
        textSearchTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, !isLookingUp else { return }
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
                scanState = .found
            } else {
                // ISBN not found — don't show error, let text fallback continue
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

    // MARK: - Title/Author Search (Tier 3)

    private func searchByAccumulatedText() async {
        // Pick the longest text fragment as the most likely title
        guard let bestCandidate = accumulatedText
            .filter({ $0.count >= 4 })
            .filter({ !$0.allSatisfy(\.isNumber) }) // Skip pure numbers
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
        searchResults = []
        errorMessage = nil
        isLookingUp = false
        accumulatedText = []
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
