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
    case .restaurantShare: return "Restaurant shared"
    }
}

/// Text block shared by all notification rows; keep tappable chrome in the caller so the avatar stays outside links/buttons.
private func notificationBody(_ item: AppNotification) -> some View {
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
    .frame(maxWidth: .infinity, alignment: .leading)
    .multilineTextAlignment(.leading)
}

/// Non-interactive row (avatar supplied by caller; avoids `NavigationLink` chevrons in lists).
private struct NotificationRow<A: View>: View {
    let item: AppNotification
    @ViewBuilder var avatar: () -> A

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            avatar()
            notificationBody(item)
        }
        .padding(.vertical, 4)
    }
}

private enum NotificationNav: Hashable {
    case userProfile(String)
    case post(String)
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
    @EnvironmentObject private var mapVM: MapViewModel
    @EnvironmentObject private var tabRouter: TabRouter
    @StateObject private var vm = NotificationsViewModel()
    @State private var notificationNav: NotificationNav?

    var body: some View {
        Group {
            if vm.isLoading && vm.items.isEmpty {
                ProgressView()
            } else if let err = vm.errorMessage, !err.isEmpty, vm.items.isEmpty {
                ContentUnavailableView("Could not load", systemImage: "bell.slash", description: Text(err))
            } else if vm.items.isEmpty {
                ContentUnavailableView("No notifications yet", systemImage: "bell", description: Text("Likes, comments, mentions, friend activity, shared restaurants, and friend requests show up here."))
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
        .navigationDestination(item: $notificationNav) { dest in
            switch dest {
            case .userProfile(let id):
                UserPostsView(userId: id)
            case .post(let id):
                NotificationPostView(postId: id)
            }
        }
        .refreshable { await vm.load() }
        .task { await vm.load() }
    }

    private func notificationActorAvatar(_ item: AppNotification) -> some View {
        Button {
            notificationNav = .userProfile(item.actorId)
        } label: {
            ProfileAvatarView(
                url: item.actorAvatarUrl,
                name: actorTitle(item),
                size: 44
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func notificationCell(_ item: AppNotification) -> some View {
        switch item.type {
        case .friendRequest:
            VStack(alignment: .leading, spacing: 8) {
                NotificationRow(item: item) {
                    notificationActorAvatar(item)
                }
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
            HStack(alignment: .top, spacing: 12) {
                notificationActorAvatar(item)
                Button {
                    notificationNav = .userProfile(item.actorId)
                } label: {
                    notificationBody(item)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
        case .restaurantShare:
            if let rid = item.restaurantId, !rid.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    notificationActorAvatar(item)
                    Button {
                        Task {
                            let ok = await mapVM.focusRestaurantFromShare(restaurantId: rid)
                            if ok { tabRouter.openMap() }
                        }
                    } label: {
                        notificationBody(item)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            } else {
                NotificationRow(item: item) {
                    notificationActorAvatar(item)
                }
            }
        default:
            if let pid = item.postId {
                HStack(alignment: .top, spacing: 12) {
                    notificationActorAvatar(item)
                    Button {
                        notificationNav = .post(pid)
                    } label: {
                        notificationBody(item)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            } else {
                NotificationRow(item: item) {
                    notificationActorAvatar(item)
                }
            }
        }
    }
}
