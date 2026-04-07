import Foundation

struct DJList: Identifiable, Codable, Hashable, Sendable {
    let ownership: OwnershipType
    let format: BookFormat

    var id: String { key }
    var key: String { ownership.listKey(for: format) }
    var displayName: String { "\(ownership.rawValue) · \(format.rawValue)" }

    var icon: String { format.icon }

    /// All 8 DJ lists
    static let all: [DJList] = OwnershipType.allCases.flatMap { ownership in
        BookFormat.allCases.map { format in
            DJList(ownership: ownership, format: format)
        }
    }

    static let owned: [DJList] = all.filter { $0.ownership == .owned }
    static let wanted: [DJList] = all.filter { $0.ownership == .want }
}
