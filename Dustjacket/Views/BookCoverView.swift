import SwiftUI

struct BookCoverView: View {
    let url: String?
    var width: CGFloat = 100
    var height: CGFloat = 150
    var cornerRadius: CGFloat = 8

    var body: some View {
        if let urlString = url, let imageURL = URL(string: urlString) {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: width, height: height)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))

                case .failure:
                    placeholder

                case .empty:
                    placeholder
                        .overlay {
                            ProgressView()
                                .tint(.secondary)
                        }

                @unknown default:
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.quaternary)
            .frame(width: width, height: height)
            .overlay {
                Image(systemName: "book.closed.fill")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
            }
    }
}
