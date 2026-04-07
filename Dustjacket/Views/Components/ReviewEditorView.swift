import SwiftUI

struct ReviewEditorView: View {
    let bookTitle: String
    @State var reviewText: String
    @State var hasSpoilers: Bool = false
    var onSave: (String, Bool) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextEditor(text: $reviewText)
                    .frame(minHeight: 200)
                    .padding(8)
                    .background(.quaternary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Toggle(isOn: $hasSpoilers) {
                    Label("Contains Spoilers", systemImage: "eye.slash")
                        .font(.subheadline)
                }

                Spacer()

                Button {
                    onSave(reviewText, hasSpoilers)
                    dismiss()
                } label: {
                    Text("Save Review")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(reviewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .navigationTitle("Review: \(bookTitle)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
