import XCTest
@testable import Dustjacket

@MainActor
final class ScannerManagerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        resetSharedState()
    }

    override func tearDown() {
        resetSharedState()
        super.tearDown()
    }

    func testBarcodeLookupNormalizesAddonAndFindsBook() async throws {
        let service = TestHardcoverService()
        service.editionByISBNResult = [makeEdition(bookId: 42, bookTitle: "The Scanner Fix")]
        let manager = ScannerManager(hardcoverService: service)

        manager.handleBarcodeDetected("9780306406157 52499")
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(service.editionByISBNCalls, ["9780306406157"])
        XCTAssertEqual(manager.scanState, .found)
        XCTAssertEqual(manager.foundBook?.id, 42)
        XCTAssertEqual(manager.lastScannedISBN, "9780306406157")
    }

    func testFailedLookupTransitionsToNotFound() async throws {
        let service = TestHardcoverService()
        let manager = ScannerManager(hardcoverService: service)

        manager.handleTextDetected("ISBN 978-0-306-40615-7")
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(service.editionByISBNCalls, ["9780306406157"])
        XCTAssertEqual(manager.scanState, .notFound)
        XCTAssertNil(manager.foundBook)
        XCTAssertEqual(manager.lastScannedISBN, "9780306406157")
    }
}
