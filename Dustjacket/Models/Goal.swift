import Foundation

struct Goal: Identifiable, Codable, Sendable {
    let id: Int
    let target: Int
    let metric: String
    let description: String?
    let startDate: String?
    let endDate: String?
    let completedAt: String?
    let archived: Bool

    var isCompleted: Bool { completedAt != nil }
    var isActive: Bool { !archived && !isCompleted }

    var metricLabel: String {
        switch metric.lowercased() {
        case "books": return "books"
        case "pages": return "pages"
        default: return metric
        }
    }
}
