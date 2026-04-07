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

                    VStack {
                        Spacer()
                        Text("Point at a barcode or printed ISBN")
                            .font(.caption)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                        Spacer().frame(height: 40)
                    }
                } else {
                    ContentUnavailableView(
                        "Camera Not Available",
                        systemImage: "camera.fill",
                        description: Text("Barcode scanning requires camera access. Please enable it in Settings.")
                    )
                }

            case .lookingUp:
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Looking up book...")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

            case .found:
                if let book = manager.foundBook {
                    ScrollView {
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
                            .padding(.horizontal)
                            .padding(.top, 8)

                            BookDetailView(book: book)
                        }
                    }
                }

            case .notFound:
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
