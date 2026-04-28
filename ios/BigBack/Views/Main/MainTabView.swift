import SwiftUI

extension Notification.Name {
    /// Posted after a new visit post is created successfully so tabs can reload server-backed lists.
    static let bigBackDidCreatePost = Notification.Name("bigBackDidCreatePost")
}

struct MainTabView: View {
    @ObservedObject var auth: AuthViewModel
    @StateObject private var mapVM = MapViewModel()
    @StateObject private var tabRouter = TabRouter()

    var body: some View {
        TabView(selection: Binding(
            get: { tabRouter.selectedTab },
            set: { tabRouter.selectedTab = $0 }
        )) {
            FeedTab()
                .tabItem { Label("Feed", systemImage: "doc.text.fill") }
                .tag(TabRouter.Tab.feed.rawValue)

            MapTabView()
                .tabItem { Label("Map", systemImage: "map.fill") }
                .tag(TabRouter.Tab.map.rawValue)

            CreateTab(currentUserId: auth.currentUser?.id ?? "")
                .tabItem { Label("Post", systemImage: "plus.circle.fill") }
                .tag(TabRouter.Tab.create.rawValue)

            BlendTab(currentUserId: auth.currentUser?.id ?? "")
                .tabItem { Label("Blend", systemImage: "sparkles") }
                .tag(TabRouter.Tab.blend.rawValue)

            MoreTab(auth: auth)
                .tabItem { Label("More", systemImage: "person.fill") }
                .tag(TabRouter.Tab.more.rawValue)
        }
        .environmentObject(mapVM)
        .environmentObject(tabRouter)
        .tint(.orange)
    }
}

// MARK: - Feed Tab
struct FeedTab: View {
    @EnvironmentObject private var mapVM: MapViewModel
    @EnvironmentObject private var tabRouter: TabRouter
    @StateObject private var feedVM = FeedViewModel()
    @State private var selectedPost: Post?

    var body: some View {
        NavigationStack {
            Group {
                if feedVM.isLoading && feedVM.posts.isEmpty {
                    ProgressView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if let err = feedVM.errorMessage {
                                ContentUnavailableView(
                                    "Couldn't load feed",
                                    systemImage: "wifi.exclamationmark",
                                    description: Text(err)
                                )
                                Button("Try again") {
                                    Task { await feedVM.loadFeed() }
                                }
                                .buttonStyle(.borderedProminent)
                                .padding(.bottom, 8)
                            }
                            ForEach(feedVM.posts) { post in
                                PostCardView(
                                    post: post,
                                    onLike: { postId in await feedVM.likePost(postId: postId) },
                                    onRestaurantTap: {
                                        mapVM.focusRestaurantFromPost(post)
                                        tabRouter.openMap()
                                    },
                                    onOpenDetail: { selectedPost = post }
                                )
                            }
                            if feedVM.posts.isEmpty && !feedVM.isLoading && feedVM.errorMessage == nil {
                                ContentUnavailableView(
                                    "No posts yet",
                                    systemImage: "doc.text",
                                    description: Text(
                                        "Posts from you and your friends appear here. Try creating a visit or connecting with friends."
                                    )
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .refreshable { await feedVM.loadFeed() }
            .navigationTitle("Feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        NotificationsView()
                    } label: {
                        Image(systemName: "bell")
                    }
                }
            }
            .navigationDestination(item: $selectedPost) { p in
                PostDetailView(
                    post: p,
                    onLike: { postId in await feedVM.likePost(postId: postId) },
                    onRestaurantTap: {
                        mapVM.focusRestaurantFromPost(p)
                        tabRouter.openMap()
                    }
                )
            }
        }
        .task { await feedVM.loadFeed() }
        .onReceive(NotificationCenter.default.publisher(for: .bigBackDidCreatePost)) { _ in
            Task { await feedVM.loadFeed() }
        }
    }
}

// MARK: - Map Tab
struct MapTabView: View {
    @EnvironmentObject private var mapVM: MapViewModel
    @State private var restaurantNav: RestaurantMapNav?

    var body: some View {
        NavigationStack {
            BigBackMapView { restaurantId, name in
                restaurantNav = RestaurantMapNav(restaurantId: restaurantId, name: name)
            }
            .environmentObject(mapVM)
            .navigationTitle("Map")
            .navigationDestination(item: $restaurantNav) { nav in
                RestaurantPostsView(restaurantId: nav.restaurantId, restaurantName: nav.name)
            }
        }
        .task { await mapVM.loadPosts() }
        .onReceive(NotificationCenter.default.publisher(for: .bigBackDidCreatePost)) { _ in
            Task { await mapVM.loadPosts() }
        }
    }
}

// MARK: - Create Tab
struct CreateTab: View {
    @EnvironmentObject private var mapVM: MapViewModel
    @StateObject private var createVM: CreatePostViewModel
    @State private var showRestaurantPicker = false

    init(currentUserId: String) {
        _createVM = StateObject(wrappedValue: CreatePostViewModel())
    }

    var body: some View {
        NavigationStack {
            CreatePostView(vm: createVM, showRestaurantPicker: $showRestaurantPicker)
                .sheet(isPresented: $showRestaurantPicker) {
                    NavigationStack {
                        RestaurantPickerSheet(
                            onSelect: { restaurant in
                                createVM.selectedRestaurant = restaurant
                                showRestaurantPicker = false
                            }
                        )
                        .environmentObject(mapVM)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") {
                                    showRestaurantPicker = false
                                }
                            }
                        }
                    }
                }
                .alert("Success", isPresented: .constant(createVM.didPost)) {
                    Button("OK") { createVM.reset() }
                } message: {
                    Text("Your post is live!")
                }
                .navigationTitle("New Post")
        }
    }
}

// MARK: - Blend Tab
struct BlendTab: View {
    @StateObject private var blendVM: BlendViewModel

    init(currentUserId: String) {
        _blendVM = StateObject(wrappedValue: BlendViewModel(currentUserId: currentUserId))
    }

    var body: some View {
        NavigationStack {
            BlendView()
                .environmentObject(blendVM)
                .navigationTitle("Taste Blend")
        }
        .task { await blendVM.loadFriends() }
    }
}

// MARK: - More Tab
struct MoreTab: View {
    @ObservedObject var auth: AuthViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    NavigationLink {
                        EditProfileView()
                    } label: {
                        Label("Edit profile", systemImage: "person.crop.circle")
                    }

                    NavigationLink {
                        FriendsView()
                            .navigationTitle("Friends")
                    } label: {
                        Label("Friends", systemImage: "person.2.fill")
                    }

                    NavigationLink {
                        SavedPlacesView()
                            .navigationTitle("Saved Places")
                    } label: {
                        Label("Saved Places", systemImage: "bookmark.fill")
                    }

                    NavigationLink {
                        UserPostsView(userId: auth.currentUser?.id ?? "")
                    } label: {
                        Label("My Posts", systemImage: "doc.text.fill")
                    }
                }

                Section("Restaurants") {
                    NavigationLink {
                        RestaurantSearchView()
                            .navigationTitle("Search Restaurants")
                    } label: {
                        Label("Find Restaurants", systemImage: "magnifyingglass")
                    }
                }

                Section {
                    Button("Log Out", role: .destructive) {
                        auth.logout()
                    }
                } footer: {
                    Text("v1.0.0")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("More")
        }
    }
}
