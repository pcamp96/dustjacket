import SwiftUI

struct ActivityView: View {
    @StateObject private var activityManager = ActivityManager.shared

    var body: some View {
        Group {
            if activityManager.isLoading && activityManager.activities.isEmpty {
                ProgressView("Loading activity...")
            } else if activityManager.activities.isEmpty {
                ContentUnavailableView(
                    "No Activity Yet",
                    systemImage: "bell.fill",
                    description: Text("Your reading activity will appear here as you add and read books.")
                )
            } else {
                List(activityManager.activities) { activity in
                    HStack(spacing: 12) {
                        if let coverURL = activity.bookCoverURL, let url = URL(string: coverURL) {
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 4).fill(.quaternary)
                            }
                            .frame(width: 40, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            if let title = activity.bookTitle {
                                Text(title)
                                    .font(.subheadline.bold())
                                    .lineLimit(1)
                            }

                            Text("You \(activity.event)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if !activity.createdAt.isEmpty {
                                Text(activity.createdAt.prefix(10))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Activity")
        .task {
            await activityManager.fetchActivities()
        }
        .refreshable {
            await activityManager.fetchActivities()
        }
    }
}
