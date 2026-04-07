import SwiftUI

struct BookCardView: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            BookCoverView(url: book.coverURL)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.caption.bold())
                    .lineLimit(2)

                if !book.authorNames.isEmpty {
                    Text(book.displayAuthor)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}
