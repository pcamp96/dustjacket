import XCTest
import SwiftData
@testable import Dustjacket

@MainActor
final class SessionCleanupTests: XCTestCase {
    override func setUp() {
        super.setUp()
        resetSharedState()
    }

    override func tearDown() {
        resetSharedState()
        super.tearDown()
    }

    func testSignOutClearsPersistedStateAndManagerCaches() async throws {
        let container = try makeInMemoryModelContainer()
        let context = container.mainContext

        context.insert(CachedBook(hardcoverID: 1, title: "Cached"))
        context.insert(CachedEdition(hardcoverID: 2, bookHardcoverID: 1))
        context.insert(ListMapping(djListKey: OwnershipType.owned.listKey(for: .hardback), hardcoverListId: 3, hardcoverListName: "Owned"))
        context.insert(
            PendingMutation(
                mutationType: "insert_list_book",
                payload: try JSONEncoder().encode(MutationPayload(bookId: 1, listId: 3))
            )
        )
        try context.save()

        LibraryManager.shared.addBookOptimistically(Book(from: makeBookModel(id: 1, title: "Live")))

        SessionCleanup.signOut(context: context)

        XCTAssertTrue(LibraryManager.shared.books.isEmpty)
        XCTAssertEqual(try context.fetch(FetchDescriptor<CachedBook>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<CachedEdition>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ListMapping>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PendingMutation>()).count, 0)
    }
}
