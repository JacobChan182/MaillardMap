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

struct PostCardView: View {
    let post: Post
    let onLike: (String) async -> Void
    var onRestaurantTap: (() -> Void)?

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

    init(post: Post, onLike: @escaping (String) async -> Void, onRestaurantTap: (() -> Void)? = nil) {
        self.post = post
        self.onLike = onLike
        self.onRestaurantTap = onRestaurantTap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                ProfileAvatarView(url: post.avatarUrl, name: authorDisplayName, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(authorDisplayName)
                        .font(.headline)
                    if post.displayName != nil,
                       let dn = post.displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !dn.isEmpty,
                       dn.caseInsensitiveCompare(post.username) != .orderedSame {
                        Text("@\(post.username)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
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

            if !post.photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(post.photos.sorted(by: { $0.orderIndex < $1.orderIndex })) { photo in
                            AsyncImage(url: URL(string: photo.url)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Color.gray.opacity(0.3)
                            }
                            .frame(height: 160)
                            .frame(width: UIScreen.main.bounds.width * 0.7)
                            .cornerRadius(8)
                        }
                    }
                }
            }

            if let comment = post.comment, !comment.isEmpty {
                Text(comment)
                    .font(.body)
                    .lineLimit(3)
            }

            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Image(systemName: post.liked ? "heart.fill" : "heart")
                            .foregroundStyle(post.liked ? .red : .secondary)
                        Text(likeCountLabel)
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                    .onTapGesture { Task { await onLike(post.id) } }

                    HStack(spacing: 6) {
                        Image(systemName: "text.bubble")
                            .foregroundStyle(.secondary)
                        Text(commentCountLabel)
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                    .onTapGesture { showComments = true }
                }
                Spacer(minLength: 8)
                if let created = postCreatedDate(from: post.createdAt) {
                    Text(relativePostAge(from: created))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.gray.opacity(0.35), lineWidth: 1)
        }
        .shadow(radius: 2)
        .sheet(isPresented: $showComments) {
            NavigationStack {
                CommentsView(postId: post.id)
                    .navigationTitle("Comments")
                    .navigationBarTitleDisplayMode(NavigationBarItem.TitleDisplayMode.inline)
            }
            .presentationDetents([.medium, .large])
        }
    }
}
