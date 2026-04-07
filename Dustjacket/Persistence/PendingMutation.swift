import Foundation
import SwiftData

@Model
final class PendingMutation {
    var id: UUID
    var mutationType: String
    var payload: Data
    var createdAt: Date
    var status: String
    var retryCount: Int
    var lastError: String?

    init(
        id: UUID = UUID(),
        mutationType: String,
        payload: Data,
        createdAt: Date = .now,
        status: String = "pending",
        retryCount: Int = 0,
        lastError: String? = nil
    ) {
        self.id = id
        self.mutationType = mutationType
        self.payload = payload
        self.createdAt = createdAt
        self.status = status
        self.retryCount = retryCount
        self.lastError = lastError
    }
}
