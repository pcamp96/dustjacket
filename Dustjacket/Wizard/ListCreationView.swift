import SwiftUI

struct ListCreationView: View {
    let progress: Int
    let total: Int

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView(value: Double(progress), total: Double(max(total, 1)))
                .progressViewStyle(.linear)
                .padding(.horizontal, 40)

            VStack(spacing: 8) {
                Text("Creating Lists...")
                    .font(.headline)

                Text("\(progress) of \(total)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Please wait — lists must be created one at a time to avoid conflicts.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
    }
}
