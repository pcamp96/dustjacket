import SwiftUI

struct StatusPickerView: View {
    let currentStatusId: Int?
    let userBookId: Int?
    let bookId: Int
    var onStatusChanged: (Int) -> Void
    var onRemove: (() -> Void)?

    var body: some View {
        VStack(spacing: 8) {
            // Status buttons in a 2x2 grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(ReadingStatus.allCases) { status in
                    Button {
                        onStatusChanged(status.rawValue)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: status.icon)
                            Text(status.label)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(currentStatusId == status.rawValue
                            ? AnyShapeStyle(statusColor(for: status).opacity(0.2))
                            : AnyShapeStyle(.quaternary))
                        .foregroundStyle(currentStatusId == status.rawValue
                            ? statusColor(for: status)
                            : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Remove button (only shown when book is in library)
            if userBookId != nil {
                Button(role: .destructive) {
                    onRemove?()
                } label: {
                    Label("Remove from Library", systemImage: "trash")
                        .font(.caption)
                }
                .padding(.top, 4)
            }
        }
    }

    private func statusColor(for status: ReadingStatus) -> Color {
        switch status {
        case .wantToRead: return .blue
        case .currentlyReading: return .orange
        case .read: return .green
        case .didNotFinish: return .red
        }
    }
}
