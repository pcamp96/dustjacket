import SwiftUI

struct SocialView: View {
    var body: some View {
        ContentUnavailableView(
            "Social",
            systemImage: "person.2.fill",
            description: Text("See who you follow and who follows you.")
        )
        .navigationTitle("Social")
    }
}
