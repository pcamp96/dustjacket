import Foundation
import SwiftData

@MainActor
final class EditionImportManager: ObservableObject {
    static let shared = EditionImportManager()

    private let pollAttempts = 10
    private let pollInterval: Duration = .seconds(3)

    private var hardcoverService: HardcoverServiceProtocol?
    private var modelContext: ModelContext?

    private init() {}

    func configure(service: HardcoverServiceProtocol, context: ModelContext) {
        self.hardcoverService = service
        self.modelContext = context
    }

    func lookupISBN(_ isbn: String, source: ISBNImportSource) async throws -> ISBNLookupOutcome {
        guard let cleaned = ISBNLookupService.normalizedISBN(from: isbn) else {
            throw GraphQLClientError.graphQLErrors(["Invalid ISBN"])
        }

        let existingPending = pendingImportStatus(for: cleaned)

        do {
            if let edition = try await lookupEdition(for: cleaned) {
                deletePendingImport(isbn: cleaned)
                return .found(edition)
            }
        } catch {
            if let existingPending {
                updatePendingCheckTimestamp(isbn: cleaned, lastError: error.localizedDescription)
                return .pending(pendingImportStatus(for: cleaned) ?? existingPending)
            }
            throw error
        }

        if let pending = existingPending {
            let refreshed = await refreshPendingImportIfPossible(for: pending)
            return refreshed ?? .pending(pending)
        }

        return .missing(
            MissingEditionDraft(
                isbn: cleaned,
                source: source,
                title: "",
                authorNamesText: "",
                format: nil,
                pageCount: nil,
                releaseYear: ""
            )
        )
    }

    func submitImport(_ draft: MissingEditionDraft) async throws -> ISBNLookupOutcome {
        let cleaned = draft.isbn

        if let edition = try await lookupEdition(for: cleaned) {
            deletePendingImport(isbn: cleaned)
            return .found(edition)
        }

        let result = try await service().upsertBookByISBN(cleaned)

        if let edition = result.edition {
            deletePendingImport(isbn: cleaned)
            return .found(edition)
        }

        if !result.wasAccepted, !result.errors.isEmpty {
            throw GraphQLClientError.graphQLErrors(result.errors)
        }

        let pending = upsertPendingImport(from: draft, lastCheckedAt: .now, lastError: nil)
        return try await pollForEdition(from: pending)
    }

    func checkPendingImport(_ isbn: String) async -> ISBNLookupOutcome? {
        guard let cleaned = ISBNLookupService.normalizedISBN(from: isbn),
              let pending = pendingImportStatus(for: cleaned) else {
            return nil
        }

        return await refreshPendingImportIfPossible(for: pending) ?? .pending(pending)
    }

    func refreshPendingImports() async {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<PendingEditionImportRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let records = (try? context.fetch(descriptor)) ?? []

        for record in records {
            if (try? await lookupEdition(for: record.isbn)) != nil {
                deletePendingImport(isbn: record.isbn)
            } else {
                record.lastCheckedAt = .now
            }
        }

        try? context.save()
    }

    private func service() throws -> HardcoverServiceProtocol {
        guard let hardcoverService else {
            throw GraphQLClientError.noToken
        }
        return hardcoverService
    }

    private func lookupEdition(for isbn: String) async throws -> Edition? {
        let service = try service()
        let editions = try await service.getEditionByISBN(isbn)
        if let first = editions.first {
            return Edition(from: first)
        }

        if isbn.count == 10 {
            let isbn13 = ISBNLookupService(hardcoverService: service).convertISBN10to13(isbn)
            let converted = try await service.getEditionByISBN(isbn13)
            if let first = converted.first {
                return Edition(from: first)
            }
        }

        return nil
    }

    private func pollForEdition(from pending: PendingEditionImportStatus) async throws -> ISBNLookupOutcome {
        for attempt in 0..<pollAttempts {
            if attempt > 0 {
                try await Task.sleep(for: pollInterval)
            }

            if let edition = try await lookupEdition(for: pending.isbn) {
                deletePendingImport(isbn: pending.isbn)
                return .found(edition)
            }

            updatePendingCheckTimestamp(isbn: pending.isbn, lastError: nil)
        }

        return .pending(pendingImportStatus(for: pending.isbn) ?? pending)
    }

    private func refreshPendingImportIfPossible(for pending: PendingEditionImportStatus) async -> ISBNLookupOutcome? {
        do {
            if let edition = try await lookupEdition(for: pending.isbn) {
                deletePendingImport(isbn: pending.isbn)
                return .found(edition)
            }

            updatePendingCheckTimestamp(isbn: pending.isbn, lastError: nil)
            return nil
        } catch {
            updatePendingCheckTimestamp(isbn: pending.isbn, lastError: error.localizedDescription)
            return .pending(pendingImportStatus(for: pending.isbn) ?? pending)
        }
    }

    private func pendingImportStatus(for isbn: String) -> PendingEditionImportStatus? {
        guard let context = modelContext else { return nil }

        let descriptor = FetchDescriptor<PendingEditionImportRecord>(
            predicate: #Predicate { $0.isbn == isbn }
        )

        guard let record = (try? context.fetch(descriptor))?.first else { return nil }

        return PendingEditionImportStatus(
            isbn: record.isbn,
            source: ISBNImportSource(rawValue: record.sourceRawValue) ?? .search,
            title: record.title,
            authorNamesText: record.authorNamesText,
            format: record.formatRawValue.flatMap(BookFormat.init(rawValue:)),
            pageCount: record.pageCount,
            releaseYear: record.releaseYear,
            createdAt: record.createdAt,
            lastCheckedAt: record.lastCheckedAt,
            lastError: record.lastError
        )
    }

    @discardableResult
    private func upsertPendingImport(from draft: MissingEditionDraft, lastCheckedAt: Date?, lastError: String?) -> PendingEditionImportStatus {
        let isbn = draft.isbn

        guard let context = modelContext else {
            return PendingEditionImportStatus(
                isbn: isbn,
                source: draft.source,
                title: draft.title,
                authorNamesText: draft.authorNamesText,
                format: draft.format,
                pageCount: draft.pageCount,
                releaseYear: draft.releaseYear,
                createdAt: .now,
                lastCheckedAt: lastCheckedAt,
                lastError: lastError
            )
        }

        let descriptor = FetchDescriptor<PendingEditionImportRecord>(
            predicate: #Predicate { $0.isbn == isbn }
        )
        let record: PendingEditionImportRecord
        if let existing = (try? context.fetch(descriptor))?.first {
            record = existing
        } else {
            record = PendingEditionImportRecord(
                isbn: isbn,
                sourceRawValue: draft.source.rawValue
            )
            context.insert(record)
        }

        record.sourceRawValue = draft.source.rawValue
        record.title = draft.title
        record.authorNamesText = draft.authorNamesText
        record.formatRawValue = draft.format?.rawValue
        record.pageCount = draft.pageCount
        record.releaseYear = draft.releaseYear
        record.lastCheckedAt = lastCheckedAt
        record.lastError = lastError

        try? context.save()
        return pendingImportStatus(for: isbn) ?? PendingEditionImportStatus(
            isbn: isbn,
            source: draft.source,
            title: draft.title,
            authorNamesText: draft.authorNamesText,
            format: draft.format,
            pageCount: draft.pageCount,
            releaseYear: draft.releaseYear,
            createdAt: record.createdAt,
            lastCheckedAt: lastCheckedAt,
            lastError: lastError
        )
    }

    private func updatePendingCheckTimestamp(isbn: String, lastError: String?) {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<PendingEditionImportRecord>(
            predicate: #Predicate { $0.isbn == isbn }
        )
        guard let record = (try? context.fetch(descriptor))?.first else { return }

        record.lastCheckedAt = .now
        record.lastError = lastError
        try? context.save()
    }

    private func deletePendingImport(isbn: String) {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<PendingEditionImportRecord>(
            predicate: #Predicate { $0.isbn == isbn }
        )
        guard let record = (try? context.fetch(descriptor))?.first else { return }

        context.delete(record)
        try? context.save()
    }
}
