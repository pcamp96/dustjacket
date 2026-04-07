import Foundation
import Vision

@MainActor
final class ScannerManager: ObservableObject {
    @Published var scanState: ScanState = .scanning
    @Published var scannedEdition: Edition?
    @Published var foundBook: Book?
    @Published var errorMessage: String?
    @Published var isLookingUp = false

    private let isbnLookup: ISBNLookupService
    private var failedISBNs: Set<String> = []

    init(hardcoverService: HardcoverServiceProtocol) {
        self.isbnLookup = ISBNLookupService(hardcoverService: hardcoverService)
    }

    // MARK: - Tier 1: Barcode

    func handleBarcodeDetected(_ barcode: String) async {
        guard !isLookingUp else { return }

        let isbn = barcode.filter(\.isNumber)
        guard isbn.count == 10 || isbn.count == 13 else {
            return
        }

        await lookupISBN(isbn)
    }

    // MARK: - Tier 2: ISBN in text

    func handleTextDetected(_ text: String) async {
        guard !isLookingUp else { return }
        guard scanState == .scanning else { return }

        if let isbn = ISBNLookupService.extractISBN(from: text), !failedISBNs.contains(isbn) {
            await lookupISBN(isbn)
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
                let book = Book(
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
                    progressSeconds: nil
                )
                foundBook = book
                scanState = .found
            } else {
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

    // MARK: - Reset

    func reset() {
        scanState = .scanning
        scannedEdition = nil
        foundBook = nil
        errorMessage = nil
        isLookingUp = false
        failedISBNs = []
    }
}

// MARK: - Scan State

enum ScanState: Equatable {
    case scanning
    case lookingUp
    case found
    case notFound
}
