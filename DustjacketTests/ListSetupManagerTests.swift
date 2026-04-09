import XCTest
import SwiftData
@testable import Dustjacket

@MainActor
final class ListSetupManagerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        resetSharedState()
    }

    override func tearDown() {
        resetSharedState()
        super.tearDown()
    }

    func testCreateMissingListsReplacesExistingMappings() async throws {
        let container = try makeInMemoryModelContainer()
        let context = container.mainContext
        let service = TestHardcoverService()
        let manager = ListSetupManager(hardcoverService: service)

        context.insert(
            ListMapping(
                djListKey: OwnershipType.owned.listKey(for: .hardback),
                hardcoverListId: 999,
                hardcoverListName: "Old Mapping"
            )
        )
        try context.save()

        service.userListsResults = [
            DJList.all.enumerated().map { index, list in
                makeList(id: index + 1, name: list.key, listBooks: [])
            }
        ]

        await manager.scanExistingLists()
        await manager.createMissingLists(context: context)

        let descriptor = FetchDescriptor<ListMapping>(
            sortBy: [SortDescriptor(\.djListKey)]
        )
        let mappings = try context.fetch(descriptor)

        XCTAssertEqual(mappings.count, DJList.all.count)
        XCTAssertEqual(
            mappings.first(where: { $0.djListKey == OwnershipType.owned.listKey(for: .hardback) })?.hardcoverListId,
            1
        )
    }
}
