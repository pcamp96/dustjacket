import Foundation

@MainActor
final class ScannerManager: ObservableObject {
    @Published var scanState: ScanState = .scanning
    @Published var foundBook: Book?
    @Published var missingImportDraft: MissingEditionDraft?
    @Published var pendingImport: PendingEditionImportStatus?
    @Published var lastScannedISBN: String?
    @Published var errorMessage: String?
    @Published var isLookingUp = false
    @Published private(set) var scannerSessionID = UUID()

    private let editionImportManager = EditionImportManager.shared
    private let duplicateCooldown: TimeInterval = 1.5
    private var recentAttempts: [String: Date] = [:]
    private var lookupTask: Task<Void, Never>?
    private var activeLookupID = UUID()

    init(hardcoverService _: HardcoverServiceProtocol) {}

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

        lookupTask = Task { [editionImportManager] in
            do {
                let outcome = try await editionImportManager.lookupISBN(isbn, source: .scanner)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    finishLookup(lookupID: lookupID, outcome: outcome)
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
        missingImportDraft = nil
        pendingImport = nil
        errorMessage = nil
        isLookingUp = false
        scannerSessionID = UUID()
    }

    func reset() {
        recentAttempts = [:]
        lastScannedISBN = nil
        resumeScanning()
    }

    private func finishLookup(lookupID: UUID, outcome: ISBNLookupOutcome) {
        guard lookupID == activeLookupID else { return }

        isLookingUp = false
        applyLookupOutcome(outcome)
    }

    private func finishLookupError(lookupID: UUID, error: Error) {
        guard lookupID == activeLookupID else { return }

        isLookingUp = false
        scanState = .scanning
        errorMessage = "Couldn’t look up this ISBN right now. Try again."
        scannerSessionID = UUID()
    }

    func submitMissingEditionImport() async {
        guard let missingImportDraft else { return }

        do {
            let outcome = try await editionImportManager.submitImport(missingImportDraft)
            applyLookupOutcome(outcome)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshPendingImport() async {
        guard let pendingImport,
              let outcome = await editionImportManager.checkPendingImport(pendingImport.isbn) else {
            return
        }

        applyLookupOutcome(outcome)
    }

    private func applyLookupOutcome(_ outcome: ISBNLookupOutcome) {
        errorMessage = nil

        switch outcome {
        case .found(let edition):
            foundBook = Book(from: edition)
            missingImportDraft = nil
            pendingImport = nil
            scanState = .found

        case .missing(let draft):
            foundBook = nil
            missingImportDraft = draft
            pendingImport = nil
            scanState = .missingImport

        case .pending(let pending):
            foundBook = nil
            missingImportDraft = nil
            pendingImport = pending
            scanState = .pendingImport
        }
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
    case missingImport
    case pendingImport
}
