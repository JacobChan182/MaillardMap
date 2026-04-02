import SwiftUI

/// Parses post `createdAt` ISO8601 strings from the API (with or without fractional seconds).
private func postCreatedDate(from iso: String) -> Date? {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f.date(from: iso) { return d }
    f.formatOptions = [.withInternetDateTime]
    return f.date(from: iso)
}

/// Relative age for feed cards: days (<14), then weeks (<30 days), then months (<365 days), then years.
private func relativePostAge(from postDate: Date, now: Date = Date()) -> String {
    let cal = Calendar.current
    let startPost = cal.startOfDay(for: postDate)
    let startNow = cal.startOfDay(for: now)
    guard let days = cal.dateComponents([.day], from: startPost, to: startNow).day else {
        return ""
    }
    if days <= 0 {
        return "Today"
    }
    if days < 14 {
        return "\(days) \(days == 1 ? "day" : "days") ago"
    }
    if days < 30 {
        let weeks = days / 7
        return "\(weeks) \(weeks == 1 ? "week" : "weeks") ago"
    }
    if days < 365 {
        let months = max(1, days / 30)
        return "\(months) \(months == 1 ? "month" : "months") ago"
    }
    let years = max(1, days / 365)
    return "\(years) \(years == 1 ? "year" : "years") ago"
}

/// First photo centered; if there is a second, it sits behind and peeks out on the right.
private struct PostCardStackedPhotos: View {
    let photos: [PostPhoto]

    private var sorted: [PostPhoto] {
        photos.sorted { $0.orderIndex < $1.orderIndex }
    }

    var body: some View {
        GeometryReader { geo in
            let width = min(geo.size.width * 0.82, 330)
            let height: CGFloat = 190
            let peek: CGFloat = 22
            ZStack {
                if sorted.count > 1 {
                    photoView(urlString: sorted[1].url, width: width, height: height)
                        .scaleEffect(0.93)
                        .rotationEffect(.degrees(3))
                        .offset(x: peek + 6)
                        .zIndex(0)
                }
                photoView(urlString: sorted[0].url, width: width, height: height)
                    .shadow(color: .black.opacity(0.14), radius: 4, x: 3, y: 0)
                    .zIndex(1)
            }
            .frame(width: geo.size.width, height: height, alignment: .center)
        }
        .frame(height: 190)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func photoView(urlString: String, width: CGFloat, height: CGFloat) -> some View {
        AsyncImage(url: URL(string: urlString)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                Color.gray.opacity(0.3)
            case .empty:
                Color.gray.opacity(0.2)
            @unknown default:
                Color.gray.opacity(0.3)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

enum PostCardVariant {
    /// Feed / profile lists: capped caption, card chrome, optional comments sheet.
    case feed
    /// Full-screen post detail: full caption, no card border.
    case detail
}

struct PostCardView: View {
    let post: Post
    /// Return updated post after toggling like, or `nil` on failure / no local change.
    let onLike: (String) async -> Post?
    var onRestaurantTap: (() -> Void)?
    var variant: PostCardVariant = .feed
    /// When set, tapping the card (or comment affordance) opens post detail instead of a sheet.
    var onOpenDetail: (() -> Void)? = nil

    @State private var showComments = false

    private var commentCountForDisplay: Int {
        post.commentCount
    }

    private var likeCountLabel: String {
        post.likeCount == 1 ? "1 Like" : "\(post.likeCount) Likes"
    }

    private var commentCountLabel: String {
        commentCountForDisplay == 1 ? "1 Comment" : "\(commentCountForDisplay) Comments"
    }

    private var authorDisplayName: String {
        let n = post.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return n.isEmpty ? post.username : n
    }

    init(
        post: Post,
        onLike: @escaping (String) async -> Post?,
        onRestaurantTap: (() -> Void)? = nil,
        variant: PostCardVariant = .feed,
        onOpenDetail: (() -> Void)? = nil
    ) {
        self.post = post
        self.onLike = onLike
        self.onRestaurantTap = onRestaurantTap
        self.variant = variant
        self.onOpenDetail = onOpenDetail
    }

    private var useCommentsSheet: Bool {
        variant == .feed && onOpenDetail == nil
    }

    private func openCommentsOrDetail() {
        if let onOpenDetail {
            onOpenDetail()
        } else if variant == .feed {
            showComments = true
        }
    }

    private var commentsSheetPresented: Binding<Bool> {
        Binding(
            get: { showComments && useCommentsSheet },
            set: { newVal in
                if !newVal { showComments = false }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                ProfileAvatarLink(
                    userId: post.userId,
                    url: post.avatarUrl,
                    name: authorDisplayName,
                    size: 40
                )
                VStack(alignment: .leading, spacing: 0) {
                    Text(authorDisplayName)
                        .font(.headline)
                    if post.displayName != nil,
                       let dn = post.displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !dn.isEmpty,
                       dn.caseInsensitiveCompare(post.username) != .orderedSame {
                        Text("@\(post.username)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 0)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let onRestaurantTap {
                    Button(action: onRestaurantTap) {
                        Text(post.restaurantName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .underline()
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(post.restaurantName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let r = post.rating {
                HStack {
                    Spacer(minLength: 0)
                    StarRatingDisplay(rating: r, starSize: 15)
                    Spacer(minLength: 0)
                }
            }

            if !post.photos.isEmpty {
                PostCardStackedPhotos(photos: post.photos)
                    .padding(.vertical, 6)
            }

            if let comment = post.comment, !comment.isEmpty {
                Text(comment)
                    .font(.body)
                    .lineLimit(variant == .feed ? 3 : nil)
            }

            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 16) {
                    Button {
                        Task { _ = await onLike(post.id) }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: post.liked ? "heart.fill" : "heart")
                                .foregroundStyle(post.liked ? .red : .secondary)
                            Text(likeCountLabel)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.plain)

                    Button(action: openCommentsOrDetail) {
                        HStack(spacing: 6) {
                            Image(systemName: "text.bubble")
                                .foregroundStyle(.secondary)
                            Text(commentCountLabel)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 8)
                if let created = postCreatedDate(from: post.createdAt) {
                    Text(relativePostAge(from: created))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(.top, 2)
        }
        .padding(variant == .feed ? 16 : 0)
        .padding(.bottom, variant == .detail ? 8 : 0)
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: variant == .feed ? 12 : 0))
        .overlay {
            if variant == .feed {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.gray.opacity(0.35), lineWidth: 1)
            }
        }
        .shadow(color: variant == .feed ? .black.opacity(0.12) : .clear, radius: 2, x: 0, y: 1)
        .contentShape(Rectangle())
        .onTapGesture {
            if onOpenDetail != nil { openCommentsOrDetail() }
        }
        .sheet(isPresented: commentsSheetPresented) {
            NavigationStack {
                CommentsView(postId: post.id)
                    .navigationTitle("Comments")
                    .navigationBarTitleDisplayMode(NavigationBarItem.TitleDisplayMode.inline)
            }
            .presentationDetents([.medium, .large])
        }
    }
}
