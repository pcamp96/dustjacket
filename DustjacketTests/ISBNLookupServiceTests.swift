import XCTest
@testable import Dustjacket

final class ISBNLookupServiceTests: XCTestCase {
    func testExtractISBNPrefersValidBooklandCodeWhenBarcodeHasPriceAddon() {
        XCTAssertEqual(
            ISBNLookupService.extractISBN(from: "9780306406157 52499"),
            "9780306406157"
        )
    }

    func testExtractISBNRejectsInvalidChecksum() {
        XCTAssertNil(ISBNLookupService.extractISBN(from: "ISBN 9780306406158"))
    }

    func testNormalizedISBNAcceptsHyphenatedISBN10() {
        XCTAssertEqual(
            ISBNLookupService.normalizedISBN(from: "0-306-40615-2"),
            "0306406152"
        )
    }
}
