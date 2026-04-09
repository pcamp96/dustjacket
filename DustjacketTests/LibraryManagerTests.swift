import XCTest
@testable import Dustjacket

@MainActor
final class LibraryManagerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        resetSharedState()
    }

    override func tearDown() {
        resetSharedState()
        super.tearDown()
    }

    func testLoadListMembershipsClearsStaleListBookIdentifiers() async throws {
        let container = try makeInMemoryModelContainer()
        let context = container.mainContext
        let service = TestHardcoverService()
        let manager = LibraryManager.shared
        let listId = 10

        context.insert(
            ListMapping(
                djListKey: OwnershipType.owned.listKey(for: .hardback),
                hardcoverListId: listId,
                hardcoverListName: "[DJ] Owned · Hardback"
            )
        )
        try context.save()

        service.userListsResults = [
            [makeList(id: listId, name: "[DJ] Owned · Hardback", listBooks: [makeListBook(id: 100, bookId: 1)])],
            [makeList(id: listId, name: "[DJ] Owned · Hardback", listBooks: [])]
        ]

        manager.configure(service: service, context: context)
        manager.addBookOptimistically(Book(from: makeBookModel(id: 1)))

        await manager.loadListMemberships()
        XCTAssertEqual(manager.listBookRecordId(bookId: 1, listId: listId), 100)

        await manager.loadListMemberships()
        XCTAssertNil(manager.listBookRecordId(bookId: 1, listId: listId))
    }
}
