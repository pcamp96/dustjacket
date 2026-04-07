import SwiftUI

struct AllListsView: View {
    let hardcoverService: HardcoverServiceProtocol

    @State private var lists: [HardcoverList] = []
    @State private var isLoading = false

    var body: some View {
        Group {
            if isLoading && lists.isEmpty {
                ProgressView("Loading lists...")
            } else if lists.isEmpty {
                ContentUnavailableView(
                    "No Lists",
                    systemImage: "list.bullet",
                    description: Text("You don't have any lists yet.")
                )
            } else {
                List(lists, id: \.id) { list in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(list.name)
                            .font(.body.bold())
                        if let count = list.books_count {
                            Text("\(count) books")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let description = list.description, !description.isEmpty {
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("All Lists")
        .task {
            await loadLists()
        }
        .refreshable {
            await loadLists()
        }
    }

    private func loadLists() async {
        isLoading = true
        lists = (try? await hardcoverService.getUserLists()) ?? []
        isLoading = false
    }
}
