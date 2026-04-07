import SwiftUI

struct StatsView: View {
    let user: HardcoverUser?

    @ObservedObject private var libraryManager = LibraryManager.shared

    var body: some View {
        List {
            Section("Overview") {
                statRow(label: "Total Books", value: "\(user?.books_count ?? 0)", icon: "books.vertical.fill")
                statRow(label: "Currently Reading", value: "\(currentlyReadingCount)", icon: "book.fill")
                statRow(label: "Read", value: "\(readCount)", icon: "checkmark.circle.fill")
                statRow(label: "Want to Read", value: "\(wantToReadCount)", icon: "bookmark")
            }

            Section("Library") {
                statRow(label: "Followers", value: "\(user?.followers_count ?? 0)", icon: "person.2.fill")
                statRow(label: "Following", value: "\(user?.followed_users_count ?? 0)", icon: "person.badge.plus")
            }
        }
        .navigationTitle("Stats")
    }

    private func statRow(label: String, value: String, icon: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }
    }

    private var currentlyReadingCount: Int {
        libraryManager.books.filter { $0.statusId == 2 }.count
    }

    private var readCount: Int {
        libraryManager.books.filter { $0.statusId == 3 }.count
    }

    private var wantToReadCount: Int {
        libraryManager.books.filter { $0.statusId == 1 }.count
    }
}
