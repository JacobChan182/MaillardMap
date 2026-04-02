import SwiftUI

/// Nav value pushed from the map when a pin is tapped.
struct RestaurantMapNav: Hashable, Identifiable {
    var id: String { restaurantId }
    let restaurantId: String
    let name: String
}

struct RestaurantPostsView: View {
    @EnvironmentObject private var mapVM: MapViewModel
    @EnvironmentObject private var tabRouter: TabRouter
    let restaurantId: String
    let restaurantName: String
    @StateObject private var vm: RestaurantPostsViewModel

    init(restaurantId: String, restaurantName: String) {
        self.restaurantId = restaurantId
        self.restaurantName = restaurantName
        _vm = StateObject(wrappedValue: RestaurantPostsViewModel(restaurantId: restaurantId))
    }

    var body: some View {
        Group {
            if vm.isLoading && vm.posts.isEmpty {
                ProgressView()
            } else {
                VStack(spacing: 0) {
                    if vm.ratingCount > 0, let avg = vm.averageRating {
                        HStack(spacing: 8) {
                            StarRatingDisplay(rating: avg, starSize: 18)
                            Text(String(format: "%.1f", avg))
                                .font(.subheadline.weight(.medium))
                            Text("·")
                                .foregroundStyle(.tertiary)
                                .font(.caption)
                            Text("\(vm.ratingCount) \(vm.ratingCount == 1 ? "rating" : "ratings")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        Divider()
                    }
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if let err = vm.errorMessage {
                                Text(err)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }
                            ForEach(vm.posts) { post in
                                PostCardView(
                                    post: post,
                                    onLike: { postId in await vm.likePost(postId: postId) },
                                    onRestaurantTap: {
                                        mapVM.focusRestaurantFromPost(post)
                                        tabRouter.openMap()
                                    }
                                )
                            }
                            if vm.posts.isEmpty && !vm.isLoading {
                                ContentUnavailableView(
                                    "No posts from friends here yet",
                                    systemImage: "doc.text"
                                )
                            }
                        }
                        .padding()
                    }
                    .refreshable { await vm.load() }
                }
            }
        }
        .navigationTitle(restaurantName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load() }
    }
}
