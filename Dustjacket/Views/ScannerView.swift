import SwiftUI
import VisionKit

struct ScannerView: View {
    @StateObject private var manager: ScannerManager
    let hardcoverService: HardcoverServiceProtocol

    init(hardcoverService: HardcoverServiceProtocol) {
        self.hardcoverService = hardcoverService
        _manager = StateObject(wrappedValue: ScannerManager(hardcoverService: hardcoverService))
    }

    var body: some View {
        ZStack {
            switch manager.scanState {
            case .scanning:
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    DataScannerRepresentable(
                        onBarcodeDetected: { barcode in
                            Task { await manager.handleBarcodeDetected(barcode) }
                        },
                        onTextDetected: { text in
                            Task { await manager.handleTextDetected(text) }
                        }
                    )
                    .ignoresSafeArea()

                    scanOverlay
                } else {
                    cameraUnavailableView
                }

            case .lookingUp, .processingOCR:
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Looking up book...")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

            case .searchingByText:
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Searching by cover text...")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

            case .found:
                if let edition = manager.scannedEdition {
                    ScanResultView(
                        edition: edition,
                        hardcoverService: hardcoverService,
                        onDismiss: { manager.reset() }
                    )
                }

            case .searchResults:
                searchResultsView

            case .notFound:
                notFoundView
            }
        }
    }

    // MARK: - Scan Overlay

    private var scanOverlay: some View {
        VStack {
            Spacer()

            Text("Point at a barcode, ISBN, or book cover")
                .font(.caption)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())

            Spacer().frame(height: 40)
        }
    }

    // MARK: - Search Results (from cover/title text)

    private var searchResultsView: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    manager.reset()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Scan")
                    }
                }
                Spacer()
            }
            .padding()

            Text("Is this your book?")
                .font(.headline)
                .padding(.bottom, 8)

            List(manager.searchResults, id: \.id) { result in
                Button {
                    // Look up the full book by ID to get edition details
                    Task { await selectSearchResult(result) }
                } label: {
                    HStack(spacing: 12) {
                        if let url = result.imageURL, let imageURL = URL(string: url) {
                            AsyncImage(url: imageURL) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 4).fill(.quaternary)
                            }
                            .frame(width: 44, height: 66)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        } else {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.quaternary)
                                .frame(width: 44, height: 66)
                                .overlay {
                                    Image(systemName: "book.closed.fill")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.title ?? "Unknown")
                                .font(.subheadline.bold())
                                .lineLimit(2)
                            if !result.authorNames.isEmpty {
                                Text(result.authorNames.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
    }

    private func selectSearchResult(_ result: HardcoverSearchResult) async {
        guard let bookId = result.id else { return }

        // Create a minimal edition from the search result so ScanResultView can display it
        manager.scannedEdition = Edition(
            id: 0,
            bookId: bookId,
            title: result.title,
            isbn13: nil,
            isbn10: nil,
            format: nil,
            pageCount: nil,
            releaseDate: nil,
            coverURL: result.imageURL,
            bookTitle: result.title,
            bookCoverURL: result.imageURL,
            bookSlug: nil,
            authorNames: result.authorNames,
            seriesID: nil,
            seriesName: nil,
            seriesPosition: nil
        )
        manager.scanState = .found
    }

    // MARK: - Fallback Views

    private var cameraUnavailableView: some View {
        ContentUnavailableView(
            "Camera Not Available",
            systemImage: "camera.fill",
            description: Text("Barcode scanning requires camera access. Please enable it in Settings.")
        )
    }

    private var notFoundView: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Book Not Found")
                .font(.title3.bold())

            Text("This ISBN wasn't found in Hardcover's database.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Scan Again") {
                manager.reset()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - DataScanner UIKit Wrapper

struct DataScannerRepresentable: UIViewControllerRepresentable {
    var onBarcodeDetected: (String) -> Void
    var onTextDetected: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [
                .barcode(symbologies: [.ean13, .ean8, .upce]),
                .text()
            ],
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        if !uiViewController.isScanning {
            try? uiViewController.startScanning()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onBarcodeDetected: onBarcodeDetected, onTextDetected: onTextDetected)
    }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onBarcodeDetected: (String) -> Void
        var onTextDetected: (String) -> Void
        private var lastDetected: String?
        private var hasTriggered = false

        init(onBarcodeDetected: @escaping (String) -> Void, onTextDetected: @escaping (String) -> Void) {
            self.onBarcodeDetected = onBarcodeDetected
            self.onTextDetected = onTextDetected
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !hasTriggered else { return }

            for item in addedItems {
                switch item {
                case .barcode(let barcode):
                    if let value = barcode.payloadStringValue, value != lastDetected {
                        lastDetected = value
                        hasTriggered = true
                        onBarcodeDetected(value)
                        return
                    }
                case .text(let text):
                    let recognized = text.transcript
                    if recognized != lastDetected {
                        lastDetected = recognized
                        onTextDetected(recognized)
                    }
                @unknown default:
                    break
                }
            }
        }

        func reset() {
            lastDetected = nil
            hasTriggered = false
        }
    }
}
