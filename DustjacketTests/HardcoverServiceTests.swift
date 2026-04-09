import XCTest
@testable import Dustjacket

final class HardcoverServiceTests: XCTestCase {
    func testSearchBooksEscapesSpecialCharacters() async throws {
        let client = RecordingGraphQLClient(
            nextResult: HardcoverSearchResponse(
                results: HardcoverTypesenseResults(hits: nil, found: 0)
            )
        )
        let service = HardcoverService(client: client)

        _ = try await service.searchBooks(query: "slash\\line\n\"quote\"", page: 1, perPage: 20)

        XCTAssertEqual(client.lastResponseKeyPath, "search")
        XCTAssertTrue(client.lastQuery?.contains("slash\\\\line\\n\\\"quote\\\"") == true)
    }

    func testInsertReadingJournalEscapesEventAndEntry() async throws {
        let client = RecordingGraphQLClient(
            nextResult: HardcoverMutationResponse(id: 1, errors: nil)
        )
        let service = HardcoverService(client: client)

        _ = try await service.insertReadingJournal(
            bookId: 7,
            event: "finished\"\nentry",
            entry: "note\\line",
            privacySettingId: 2
        )

        XCTAssertEqual(client.lastResponseKeyPath, "insert_reading_journal")
        XCTAssertTrue(client.lastQuery?.contains("finished\\\"\\nentry") == true)
        XCTAssertTrue(client.lastQuery?.contains("note\\\\line") == true)
    }
}
