import SwiftUI

struct JournalEditorSheet: View {
    let bookTitle: String
    var onSave: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedEvent = "note"
    @State private var entryText = ""

    private let events = [
        ("started", "Started Reading"),
        ("paused", "Paused"),
        ("finished", "Finished"),
        ("note", "Note")
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Event type
                Picker("Event", selection: $selectedEvent) {
                    ForEach(events, id: \.0) { event in
                        Text(event.1).tag(event.0)
                    }
                }
                .pickerStyle(.segmented)

                // Note text
                TextEditor(text: $entryText)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(.quaternary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Spacer()

                Button {
                    onSave(selectedEvent, entryText)
                    dismiss()
                } label: {
                    Text("Save Entry")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Journal Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
