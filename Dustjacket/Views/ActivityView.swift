import SwiftUI

struct ActivityView: View {
    var body: some View {
        ContentUnavailableView(
            "Activity Feed",
            systemImage: "bell.fill",
            description: Text("Your reading activity and social feed will appear here.")
        )
        .navigationTitle("Activity")
    }
}
