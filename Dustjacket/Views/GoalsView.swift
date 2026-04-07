import SwiftUI

struct GoalsView: View {
    var body: some View {
        VStack(spacing: 20) {
            ContentUnavailableView(
                "Reading Goals",
                systemImage: "target",
                description: Text("Set and track your reading goals. Create a goal to get started.")
            )

            Button("Create Goal") {
                // Goal creation will be wired to GoalManager CRUD
            }
            .buttonStyle(.borderedProminent)
        }
        .navigationTitle("Goals")
    }
}
