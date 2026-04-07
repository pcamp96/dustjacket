import SwiftUI

struct StarRatingView: View {
    let rating: Double
    var maxRating: Int = 5
    var onRate: ((Double) -> Void)?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...maxRating, id: \.self) { star in
                starImage(for: star)
                    .font(.title3)
                    .foregroundStyle(starColor(for: star))
                    .onTapGesture {
                        let newRating = Double(star)
                        // Tap same star to set half-star below
                        if newRating == rating {
                            onRate?(newRating - 0.5)
                        } else {
                            onRate?(newRating)
                        }
                    }
            }
        }
    }

    private func starImage(for star: Int) -> Image {
        let value = Double(star)
        if rating >= value {
            return Image(systemName: "star.fill")
        } else if rating >= value - 0.5 {
            return Image(systemName: "star.leadinghalf.filled")
        } else {
            return Image(systemName: "star")
        }
    }

    private func starColor(for star: Int) -> Color {
        Double(star) <= rating + 0.5 ? .yellow : .gray.opacity(0.3)
    }
}
