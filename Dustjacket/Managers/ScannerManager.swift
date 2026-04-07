import Foundation
import Vision

@MainActor
final class ScannerManager: ObservableObject {
    @Published var scanState: ScanState = .scanning
    @Published var scannedEdition: Edition?
    @Published var errorMessage: String?
    @Published var isLookingUp = false

    private let isbnLookup: ISBNLookupService

    init(hardcoverService: HardcoverServiceProtocol) {
        self.isbnLookup = ISBNLookupService(hardcoverService: hardcoverService)
    }

    // MARK: - Barcode Scan Result

    func handleBarcodeDetected(_ barcode: String) async {
        guard !isLookingUp else { return }

        let isbn = barcode.filter(\.isNumber)
        guard isbn.count == 10 || isbn.count == 13 else {
            errorMessage = "Not a valid ISBN barcode"
            return
        }

        await lookupISBN(isbn)
    }

    // MARK: - OCR

    func processOCRImage(_ imageData: Data) async {
        guard !isLookingUp else { return }

        scanState = .processingOCR

        // Run text recognition off-main
        let extractedISBN: String? = await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: nil)
                    return
                }

                let allText = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: " ")

                continuation.resume(returning: ISBNLookupService.extractISBN(from: allText))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false

            guard let cgImage = createCGImage(from: imageData) else {
                continuation.resume(returning: nil)
                return
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }

        if let isbn = extractedISBN {
            await lookupISBN(isbn)
        } else {
            errorMessage = "Could not find an ISBN in the image"
            scanState = .scanning
        }
    }

    // MARK: - ISBN Lookup

    func lookupISBN(_ isbn: String) async {
        isLookingUp = true
        errorMessage = nil
        scanState = .lookingUp

        do {
            if let edition = try await isbnLookup.lookup(isbn: isbn) {
                scannedEdition = edition
                scanState = .found
            } else {
                errorMessage = "Book not found in Hardcover"
                scanState = .notFound
            }
        } catch {
            errorMessage = "Lookup failed: \(error.localizedDescription)"
            scanState = .scanning
        }

        isLookingUp = false
    }

    // MARK: - Reset

    func reset() {
        scanState = .scanning
        scannedEdition = nil
        errorMessage = nil
        isLookingUp = false
    }

    // MARK: - Helpers

    private func createCGImage(from data: Data) -> CGImage? {
        guard let dataProvider = CGDataProvider(data: data as CFData),
              let cgImage = CGImage(
                  pngDataProviderSource: dataProvider,
                  decode: nil,
                  shouldInterpolate: true,
                  intent: .defaultIntent
              ) else {
            // Try JPEG
            if let uiImage = UIImageFromData(data) {
                return uiImage
            }
            return nil
        }
        return cgImage
    }

    private func UIImageFromData(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}

// MARK: - Scan State

enum ScanState: Equatable {
    case scanning
    case lookingUp
    case processingOCR
    case found
    case notFound
}
