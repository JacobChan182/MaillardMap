import SwiftUI

struct MainTabView: View {
    @ObservedObject var auth: AuthViewModel
    @StateObject private var mapVM = MapViewModel()

    var body: some View {
        TabView {
            FeedTab()
                .tabItem { Label("Feed", systemImage: "doc.text.fill") }

            MapTabView()
                .tabItem { Label("Map", systemImage: "map.fill") }

            CreateTab(currentUserId: auth.currentUser?.id ?? "")
                .tabItem { Label("Post", systemImage: "plus.circle.fill") }

            BlendTab(currentUserId: auth.currentUser?.id ?? "")
                .tabItem { Label("Blend", systemImage: "sparkles") }

            MoreTab(auth: auth)
                .tabItem { Label("More", systemImage: "person.fill") }
        }
        .environmentObject(mapVM)
        .tint(.orange)
    }
}

// MARK: - Feed Tab
struct FeedTab: View {
    @StateObject private var feedVM = FeedViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if feedVM.isLoading && feedVM.posts.isEmpty {
                    ProgressView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(feedVM.posts) { post in
                                PostCardView(post: post) { postId in
                                    await feedVM.likePost(postId: postId)
                                }
                            }
                            if feedVM.posts.isEmpty && !feedVM.isLoading {
                                ContentUnavailableView(
                                    "No posts yet",
                                    systemImage: "doc.text"
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .refreshable { await feedVM.loadFeed() }
            .navigationTitle("Feed")
        }
        .task { await feedVM.loadFeed() }
    }
}

// MARK: - Map Tab
struct MapTabView: View {
    @EnvironmentObject private var mapVM: MapViewModel

    var body: some View {
        NavigationStack {
            BigBackMapView()
                .environmentObject(mapVM)
                .navigationTitle("Map")
        }
        .task { await mapVM.loadPosts() }
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
                            .navigationTitle("My Posts")
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
