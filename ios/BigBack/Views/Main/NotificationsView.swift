import SwiftUI

private func notificationTimeLabel(iso: String) -> String {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    var d = f.date(from: iso)
    if d == nil {
        f.formatOptions = [.withInternetDateTime]
        d = f.date(from: iso)
    }
    guard let date = d else { return "" }
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: Date())
}

private func actorTitle(_ n: AppNotification) -> String {
    let d = n.actorDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return d.isEmpty ? n.actorUsername : d
}

private func typeLabel(_ kind: AppNotification.Kind) -> String {
    switch kind {
    case .friendRequest: return "Friend request"
    case .friendAccept: return "Friend request accepted"
    case .like: return "Like"
    case .comment: return "Comment"
    case .reply: return "Reply"
    case .mention: return "Mention"
    }
}

private struct NotificationRow: View {
    let item: AppNotification

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ProfileAvatarView(
                url: item.actorAvatarUrl,
                name: actorTitle(item),
                size: 44
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(typeLabel(item.type))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(actorTitle(item))
                    .font(.subheadline.weight(.semibold))
                if let preview = item.previewText, !preview.isEmpty {
                    Text(preview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                Text(notificationTimeLabel(iso: item.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

struct NotificationPostView: View {
    let postId: String
    @State private var post: Post?
    @State private var isLoading = true
    @State private var loadError: String?

    private let api = APIClient.live()

    var body: some View {
        Group {
            if let post {
                ScrollView {
                    PostCardView(
                        post: post,
                        onLike: { id in await toggleLike(id: id) },
                        onRestaurantTap: nil
                    )
                    .padding()
                }
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    "Post unavailable",
                    systemImage: "doc.text",
                    description: Text(loadError ?? "You may not be able to see this post anymore.")
                )
            }
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            post = try await api.getPost(id: postId)
        } catch {
            post = nil
            loadError = error.localizedDescription
        }
    }

    private func toggleLike(id: String) async {
        guard var p = post else { return }
        do {
            let liked = try await api.likePost(postId: id)
            p = Post(
                id: p.id, userId: p.userId, username: p.username,
                displayName: p.displayName, avatarUrl: p.avatarUrl,
                restaurantId: p.restaurantId, restaurantName: p.restaurantName,
                restaurantAddress: p.restaurantAddress,
                lat: p.lat, lng: p.lng, comment: p.comment,
                rating: p.rating,
                photos: p.photos, liked: liked,
                likeCount: liked ? p.likeCount + 1 : max(0, p.likeCount - 1),
                commentCount: p.commentCount,
                createdAt: p.createdAt
            )
            post = p
        } catch {}
    }
}

struct NotificationsView: View {
    @StateObject private var vm = NotificationsViewModel()

    var body: some View {
        Group {
            if vm.isLoading && vm.items.isEmpty {
                ProgressView()
            } else if let err = vm.errorMessage, !err.isEmpty, vm.items.isEmpty {
                ContentUnavailableView("Could not load", systemImage: "bell.slash", description: Text(err))
            } else if vm.items.isEmpty {
                ContentUnavailableView("No notifications yet", systemImage: "bell", description: Text("Likes, comments, mentions, friend requests, and accepted requests show up here."))
            } else {
                List {
                    ForEach(vm.items) { item in
                        notificationCell(item)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await vm.load() }
        .task { await vm.load() }
    }

    @ViewBuilder
    private func notificationCell(_ item: AppNotification) -> some View {
        switch item.type {
        case .friendRequest:
            VStack(alignment: .leading, spacing: 8) {
                NotificationRow(item: item)
                Button {
                    Task { await vm.acceptFriendRequest(actorId: item.actorId) }
                } label: {
                    Text("Accept")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        case .friendAccept:
            NavigationLink {
                UserPostsView(userId: item.actorId)
                    .navigationTitle("Posts")
            } label: {
                NotificationRow(item: item)
            }
        default:
            if let pid = item.postId {
                NavigationLink {
                    NotificationPostView(postId: pid)
                } label: {
                    NotificationRow(item: item)
                }
            } else {
                NotificationRow(item: item)
            }
        }
    }
}
