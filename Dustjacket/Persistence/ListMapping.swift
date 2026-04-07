import Foundation
import SwiftData

@Model
final class ListMapping {
    @Attribute(.unique) var djListKey: String
    var hardcoverListId: Int
    var hardcoverListName: String
    var createdAt: Date

    init(
        djListKey: String,
        hardcoverListId: Int,
        hardcoverListName: String,
        createdAt: Date = .now
    ) {
        self.djListKey = djListKey
        self.hardcoverListId = hardcoverListId
        self.hardcoverListName = hardcoverListName
        self.createdAt = createdAt
    }
}
