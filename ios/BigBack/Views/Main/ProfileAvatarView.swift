import SwiftUI

/// Circular avatar: remote image when `url` is set, otherwise a monogram from `name`.
struct ProfileAvatarView: View {
    var url: String?
    var name: String
    var size: CGFloat = 40

    private var monogram: String {
        let t = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let c = t.first else { return "?" }
        return String(c).uppercased()
    }

    var body: some View {
        Group {
            if let url, let u = URL(string: url), !url.isEmpty {
                AsyncImage(url: u) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        monogramView
                    case .empty:
                        ProgressView()
                    @unknown default:
                        monogramView
                    }
                }
            } else {
                monogramView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var monogramView: some View {
        Text(monogram)
            .font(.system(size: size * 0.38, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color.orange.gradient)
    }
}

#Preview {
    HStack {
        ProfileAvatarView(url: nil, name: "sam")
        ProfileAvatarView(url: "https://example.com/x.png", name: "x")
    }
}
