import Foundation

struct Goal: Identifiable, Codable, Sendable {
    let id: Int
    let target: Int
    let metric: String
    let description: String?
    let startDate: String?
    let endDate: String?
    let progress: Double?
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

    var progressPercent: Double {
        guard target > 0, let progress else { return 0 }
        return min(progress / Double(target), 1.0)
    }
}

extension Goal {
    init(from hc: HardcoverGoal) {
        self.id = hc.id
        self.target = hc.goal
        self.metric = hc.metric ?? "books"
        self.description = hc.description
        self.startDate = hc.start_date
        self.endDate = hc.end_date
        self.progress = hc.progress
        self.completedAt = hc.completed_at
        self.archived = hc.archived ?? false
    }
}
