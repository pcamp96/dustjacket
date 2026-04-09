import XCTest
import SwiftData
@testable import Dustjacket

private enum TestFailure: Error {
    case expected
}

@MainActor
final class MutationQueueTests: XCTestCase {
    override func setUp() {
        super.setUp()
        resetSharedState()
    }

    override func tearDown() {
        resetSharedState()
        super.tearDown()
    }

    func testFailedMutationIsRetainedAfterThreeRetries() async throws {
        let container = try makeInMemoryModelContainer()
        let context = container.mainContext
        let service = TestHardcoverService()
        service.addBookToListError = TestFailure.expected

        MutationQueue.shared.configure(service: service, context: context)

        let payload = try JSONEncoder().encode(MutationPayload(bookId: 1, listId: 2))
        context.insert(PendingMutation(mutationType: "insert_list_book", payload: payload))
        try context.save()

        await MutationQueue.shared.processQueue()

        let descriptor = FetchDescriptor<PendingMutation>()
        let persisted = try context.fetch(descriptor)
        XCTAssertEqual(persisted.count, 1)
        XCTAssertEqual(persisted.first?.status, "failed")
        XCTAssertEqual(persisted.first?.retryCount, 3)
        XCTAssertEqual(service.addBookToListCalls.count, 3)
    }

    func testQueuedProgressMutationCallsServiceAndIsRemoved() async throws {
        let container = try makeInMemoryModelContainer()
        let context = container.mainContext
        let service = TestHardcoverService()

        MutationQueue.shared.configure(service: service, context: context)

        let payload = try JSONEncoder().encode(
            MutationPayload(userBookId: 44, progressPercent: 55.0)
        )
        context.insert(PendingMutation(mutationType: "insert_user_book_read", payload: payload))
        try context.save()

        await MutationQueue.shared.processQueue()

        let descriptor = FetchDescriptor<PendingMutation>()
        let persisted = try context.fetch(descriptor)
        XCTAssertTrue(persisted.isEmpty)
        XCTAssertEqual(service.insertReadCalls.count, 1)
        XCTAssertEqual(service.insertReadCalls.first?.userBookId, 44)
        XCTAssertEqual(service.insertReadCalls.first?.progressPercent, 55.0)
    }
}
