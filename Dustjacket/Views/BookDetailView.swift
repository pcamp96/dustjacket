import SwiftUI

struct BookDetailView: View {
    let book: Book
    let hardcoverService: Any // Will be properly typed when needed for mutations

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Cover
                BookCoverView(url: book.coverURL, width: 180, height: 270, cornerRadius: 12)
                    .shadow(radius: 8, y: 4)

                // Title & Author
                VStack(spacing: 6) {
                    Text(book.title)
                        .font(.system(.title2, design: .serif, weight: .bold))
                        .multilineTextAlignment(.center)

                    if !book.authorNames.isEmpty {
                        Text(book.displayAuthor)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)

                // Series badge
                if let seriesName = book.seriesName {
                    HStack(spacing: 4) {
                        Image(systemName: "books.vertical")
                            .font(.caption)
                        Text(seriesName)
                        if let position = book.seriesPosition {
                            Text("#\(position, specifier: "%.0f")")
                                .fontWeight(.bold)
                        }
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.quaternary)
                    .clipShape(Capsule())
                }

                // Status
                if let statusLabel = book.statusLabel {
                    Label(statusLabel, systemImage: statusIcon(for: book.statusId))
                        .font(.subheadline)
                        .foregroundStyle(statusColor(for: book.statusId))
                }

                // Metadata
                VStack(spacing: 12) {
                    if let pages = book.pageCount {
                        metadataRow(label: "Pages", value: "\(pages)")
                    }

                    if let rating = book.rating, rating > 0 {
                        metadataRow(label: "Your Rating", value: String(repeating: "★", count: Int(rating)))
                    }
                }
                .padding()
                .background(.quaternary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                // Hardcover link
                if let url = book.hardcoverURL {
                    Link(destination: url) {
                        Label("View on Hardcover", systemImage: "safari")
                            .font(.subheadline)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func metadataRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }

    private func statusIcon(for statusId: Int?) -> String {
        switch statusId {
        case 1: return "bookmark"
        case 2: return "book.fill"
        case 3: return "checkmark.circle.fill"
        case 5: return "xmark.circle"
        default: return "questionmark.circle"
        }
    }

    private func statusColor(for statusId: Int?) -> Color {
        switch statusId {
        case 1: return .blue
        case 2: return .orange
        case 3: return .green
        case 5: return .red
        default: return .secondary
        }
    }
}
