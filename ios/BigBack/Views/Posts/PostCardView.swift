import SwiftUI

struct PostCardView: View {
    let post: Post
    let likePost: (String) async -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // User header
            HStack {
                Text(post.username)
                    .font(.headline)
                Spacer()
                Text(post.restaurantName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Photos
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
                            .frame(width:UIScreen.main.bounds.width * 0.7)
                            .cornerRadius(8)
                        }
                    }
                }
            }

            // Comment
            if let comment = post.comment, !comment.isEmpty {
                Text(comment)
                    .font(.body)
                    .lineLimit(3)
            }

            // Actions
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Label(post.liked ? "Liked" : "Like",
                          systemImage: post.liked ? "heart.fill" : "heart")
                        .foregroundStyle(post.liked ? .red : .secondary)
                    Text("\(post.likeCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }.onTapGesture { Task { await likePost(post.id) } }

                if let date = ISO8601DateFormatter().date(from: post.createdAt) {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}
