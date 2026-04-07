import Foundation

struct ReadingJournal: Identifiable, Sendable {
    let id: Int
    let bookId: Int
    let event: String
    let entry: String?
    let actionAt: String?
    let createdAt: String?

    var eventLabel: String {
        switch event.lowercased() {
        case "started": return "Started Reading"
        case "finished": return "Finished"
        case "paused": return "Paused"
        case "note": return "Note"
        default: return event.capitalized
        }
    }

    var eventIcon: String {
        switch event.lowercased() {
        case "started": return "book.fill"
        case "finished": return "checkmark.circle.fill"
        case "paused": return "pause.circle.fill"
        case "note": return "note.text"
        default: return "pencil.circle"
        }
    }
}
