import SwiftUI

/// Shows which formats a book is owned in / wanted in, with toggle buttons
struct FormatCollectionView: View {
    let bookId: Int
    let book: Book?
    @ObservedObject var libraryManager: LibraryManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Collection")
                .font(.subheadline.bold())

            ForEach(OwnershipType.allCases) { ownership in
                VStack(alignment: .leading, spacing: 6) {
                    Text(ownership.rawValue)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        ForEach(BookFormat.allCases) { format in
                            let isOn = libraryManager.isBookOnList(bookId, ownership: ownership, format: format)

                            Button {
                                libraryManager.toggleBookOnDJList(bookId: bookId, ownership: ownership, format: format, book: book)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: format.icon)
                                        .font(.system(size: 10))
                                    Text(format.rawValue)
                                        .font(.caption2)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(isOn
                                    ? AnyShapeStyle(formatColor(ownership).opacity(0.2))
                                    : AnyShapeStyle(.quaternary))
                                .foregroundStyle(isOn ? formatColor(ownership) : .secondary)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .strokeBorder(isOn ? formatColor(ownership).opacity(0.5) : .clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func formatColor(_ ownership: OwnershipType) -> Color {
        switch ownership {
        case .owned: return .green
        case .want: return .blue
        }
    }
}
