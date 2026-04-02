import SwiftUI
import UIKit

/// Circular avatar: remote image when `url` is set, otherwise a monogram from `name`.
struct ProfileAvatarView: View {
    var url: String?
    var name: String
    var size: CGFloat = 40

    @State private var resolvedImage: UIImage?
    @State private var loadFinished = false

    private var monogram: String {
        let t = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let c = t.first else { return "?" }
        return String(c).uppercased()
    }

    var body: some View {
        Group {
            if let url, let u = URL(string: url), !url.isEmpty {
                if let img = resolvedImage ?? AvatarImageLoader.cachedImage(for: u) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else if loadFinished {
                    monogramView
                } else {
                    ZStack {
                        monogramView.opacity(0.35)
                        ProgressView()
                            .scaleEffect(0.65)
                    }
                    .task(id: url) {
                        loadFinished = false
                        resolvedImage = nil
                        if let cached = AvatarImageLoader.cachedImage(for: u) {
                            resolvedImage = cached
                            loadFinished = true
                            return
                        }
                        let image = await AvatarImageLoader.load(url: u)
                        resolvedImage = image
                        loadFinished = true
                    }
                }
            } else {
                monogramView
            }
        }
        .id(url ?? "")
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

/// Opens that user's profile (`UserPostsView`). Use inside a `NavigationStack`.
struct ProfileAvatarLink: View {
    let userId: String
    var url: String?
    var name: String
    var size: CGFloat = 40

    var body: some View {
        Group {
            if userId.isEmpty {
                ProfileAvatarView(url: url, name: name, size: size)
            } else {
                NavigationLink {
                    UserPostsView(userId: userId)
                } label: {
                    ProfileAvatarView(url: url, name: name, size: size)
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityLabel("View \(name) profile")
    }
}

#Preview {
    HStack {
        ProfileAvatarView(url: nil, name: "sam")
        ProfileAvatarView(url: "https://example.com/x.png", name: "x")
    }
}
