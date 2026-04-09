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
                scannerSurface

            case .lookingUp:
                ZStack {
                    Color.black.ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Looking up \(manager.lastScannedISBN ?? "book")...")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }

            case .found:
                if let book = manager.foundBook {
                    BookDetailView(book: book)
                        .safeAreaInset(edge: .top) {
                            HStack {
                                Button {
                                    manager.reset()
                                } label: {
                                    Label("Scan Again", systemImage: "barcode.viewfinder")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .buttonStyle(.borderedProminent)

                                Spacer()

                                if let isbn = manager.lastScannedISBN {
                                    Text(isbn)
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial)
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

                    if let isbn = manager.lastScannedISBN {
                        Text(isbn)
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    Button("Scan Again") {
                        manager.reset()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 24)
            }
        }
        .overlay(alignment: .bottom) {
            if let errorMessage = manager.errorMessage, manager.scanState == .scanning {
                Text(errorMessage)
                    .font(.caption)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 24)
            }
        }
        .animation(.snappy, value: manager.scanState)
    }

    @ViewBuilder
    private var scannerSurface: some View {
        if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
            DataScannerRepresentable(
                onBarcodeDetected: { barcode in
                    Task { @MainActor in
                        manager.handleBarcodeDetected(barcode)
                    }
                },
                onTextDetected: { text in
                    Task { @MainActor in
                        manager.handleTextDetected(text)
                    }
                }
            )
            .id(manager.scannerSessionID)
            .ignoresSafeArea()
            .overlay {
                scannerOverlay
            }
        } else {
            ContentUnavailableView(
                "Camera Not Available",
                systemImage: "camera.fill",
                description: Text("Barcode scanning requires camera access. Please enable it in Settings.")
            )
        }
    }

    private var scannerOverlay: some View {
        VStack {
            Spacer()

            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(.white.opacity(0.8), lineWidth: 2)
                .frame(width: 260, height: 180)
                .overlay(alignment: .top) {
                    Text("Point at a barcode or printed ISBN")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .offset(y: -18)
                }

            Spacer()
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
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        context.coordinator.updateCallbacks(
            onBarcodeDetected: onBarcodeDetected,
            onTextDetected: onTextDetected
        )

        if !uiViewController.isScanning {
            do {
                try uiViewController.startScanning()
            } catch {
                assertionFailure("Failed to start scanner: \(error.localizedDescription)")
            }
        }
    }

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        uiViewController.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onBarcodeDetected: onBarcodeDetected, onTextDetected: onTextDetected)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private var onBarcodeDetected: (String) -> Void
        private var onTextDetected: (String) -> Void
        private let duplicateCooldown: TimeInterval = 0.75
        private var recentEmissions: [String: Date] = [:]

        init(onBarcodeDetected: @escaping (String) -> Void, onTextDetected: @escaping (String) -> Void) {
            self.onBarcodeDetected = onBarcodeDetected
            self.onTextDetected = onTextDetected
        }

        func updateCallbacks(onBarcodeDetected: @escaping (String) -> Void, onTextDetected: @escaping (String) -> Void) {
            self.onBarcodeDetected = onBarcodeDetected
            self.onTextDetected = onTextDetected
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            process(addedItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            process(updatedItems)
        }

        private func process(_ items: [RecognizedItem]) {
            pruneRecentEmissions()

            for item in items {
                if case .barcode(let barcode) = item,
                   let value = barcode.payloadStringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                   shouldEmit(value) {
                    onBarcodeDetected(value)
                    return
                }
            }

            for item in items {
                if case .text(let text) = item {
                    let transcript = text.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !transcript.isEmpty,
                          ISBNLookupService.likelyContainsISBN(transcript),
                          shouldEmit(transcript) else {
                        continue
                    }

                    onTextDetected(transcript)
                    return
                }
            }
        }

        private func shouldEmit(_ payload: String) -> Bool {
            if let lastEmission = recentEmissions[payload],
               Date().timeIntervalSince(lastEmission) < duplicateCooldown {
                return false
            }

            recentEmissions[payload] = Date()
            return true
        }

        private func pruneRecentEmissions() {
            let cutoff = Date().addingTimeInterval(-duplicateCooldown)
            recentEmissions = recentEmissions.filter { $0.value >= cutoff }
        }
    }
}
