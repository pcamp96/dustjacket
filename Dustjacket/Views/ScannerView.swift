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
                    DataScannerRepresentable(onBarcodeDetected: { barcode in
                        Task { await manager.handleBarcodeDetected(barcode) }
                    })
                    .ignoresSafeArea()

                    scanOverlay
                } else {
                    cameraUnavailableView
                }

            case .lookingUp, .processingOCR:
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text(manager.scanState == .processingOCR ? "Reading text..." : "Looking up book...")
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

            case .notFound:
                notFoundView
            }
        }
        .alert("Error", isPresented: .constant(manager.errorMessage != nil && manager.scanState == .scanning)) {
            Button("OK") { manager.errorMessage = nil }
        } message: {
            Text(manager.errorMessage ?? "")
        }
    }

    // MARK: - Scan Overlay

    private var scanOverlay: some View {
        VStack {
            Spacer()
            HStack(spacing: 16) {
                Button {
                    // Manual search fallback — switch to Search tab
                    // This will be wired to tab switching in integration
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
            }
            .padding(.bottom, 40)
        }
    }

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

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce])],
            qualityLevel: .balanced,
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
        Coordinator(onBarcodeDetected: onBarcodeDetected)
    }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onBarcodeDetected: (String) -> Void
        private var lastDetected: String?

        init(onBarcodeDetected: @escaping (String) -> Void) {
            self.onBarcodeDetected = onBarcodeDetected
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in addedItems {
                if case .barcode(let barcode) = item,
                   let value = barcode.payloadStringValue,
                   value != lastDetected {
                    lastDetected = value
                    onBarcodeDetected(value)
                }
            }
        }
    }
}
