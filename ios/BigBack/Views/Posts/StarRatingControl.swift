import SwiftUI

/// Read-only 5-star row with half-star support.
struct StarRatingDisplay: View {
    let rating: Double
    var starSize: CGFloat = 14

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                starImage(fill: min(1, max(0, rating - Double(i))))
                    .font(.system(size: starSize))
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel("\(String(format: "%.1f", rating)) out of 5 stars")
    }

    @ViewBuilder
    private func starImage(fill: CGFloat) -> some View {
        if fill >= 1 {
            Image(systemName: "star.fill").foregroundStyle(.orange)
        } else if fill >= 0.5 {
            Image(systemName: "star.lefthalf.fill").foregroundStyle(.orange)
        } else {
            Image(systemName: "star").foregroundStyle(.orange.opacity(0.35))
        }
    }
}

/// Inline 5-star control: drag or tap along the row to set half-star steps from 0.5 to 5.0.
struct StarRatingPicker: View {
    @Binding var rating: Double?

    private let starCount = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your rating")
                .font(.headline)
            HStack(spacing: 4) {
                ForEach(0..<starCount, id: \.self) { i in
                    Image(systemName: starSymbol(index: i))
                        .font(.title2)
                        .foregroundStyle(.orange)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .frame(height: 34)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { g in
                                    let w = max(geo.size.width, 1)
                                    let x = min(max(0, g.location.x), w)
                                    let halves = min(9, max(0, Int(floor((x / w) * 10))))
                                    rating = Double(halves + 1) * 0.5
                                },
                        )
                },
            )
            if let r = rating {
                Text(String(format: "%.1f stars", r))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Tap or drag to rate")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Restaurant rating")
    }

    private func starSymbol(index: Int) -> String {
        let r = rating ?? 0
        let v = min(1, max(0, r - Double(index)))
        if v >= 1 { return "star.fill" }
        if v >= 0.5 { return "star.lefthalf.fill" }
        return "star"
    }
}

#Preview("Display") {
    StarRatingDisplay(rating: 3.5)
}
