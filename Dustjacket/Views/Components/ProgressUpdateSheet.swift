import SwiftUI

struct ProgressUpdateSheet: View {
    let bookTitle: String
    let totalPages: Int?
    @State var currentPage: Int
    var onSave: (Int) -> Void
    var onMarkFinished: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Progress display
                if let total = totalPages, total > 0 {
                    VStack(spacing: 8) {
                        ProgressView(value: Double(currentPage), total: Double(total))
                            .tint(.accentColor)

                        Text("\(currentPage) of \(total) pages")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("\(Int((Double(currentPage) / Double(total)) * 100))%")
                            .font(.title2.bold())
                    }
                    .padding(.top)
                }

                // Page stepper
                VStack(spacing: 12) {
                    Text("Current Page")
                        .font(.subheadline.bold())

                    HStack(spacing: 16) {
                        Button {
                            currentPage = max(0, currentPage - 10)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                        }
                        .disabled(currentPage <= 0)

                        TextField("Page", value: $currentPage, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                            .frame(width: 80)
                            .multilineTextAlignment(.center)

                        Button {
                            let max = totalPages ?? 10000
                            currentPage = min(max, currentPage + 10)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                    }

                    // Quick jump buttons
                    if let total = totalPages, total > 0 {
                        HStack(spacing: 8) {
                            ForEach([25, 50, 75, 100], id: \.self) { pct in
                                Button("\(pct)%") {
                                    currentPage = Int(Double(total) * Double(pct) / 100.0)
                                }
                                .buttonStyle(.bordered)
                                .font(.caption)
                            }
                        }
                    }
                }

                Spacer()

                // Actions
                VStack(spacing: 12) {
                    Button {
                        onSave(currentPage)
                        dismiss()
                    } label: {
                        Text("Save Progress")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)

                    if let onMarkFinished {
                        Button {
                            onMarkFinished()
                            dismiss()
                        } label: {
                            Label("Mark as Finished", systemImage: "checkmark.circle")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding()
            .navigationTitle("Update Progress")
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
