package com.maillardmap.data

import com.maillardmap.domain.*

class Repository(
    private val api: BigBackApi,
    private val sessionManager: SessionManager
) {

    // --- Auth ---
    /** Does not save a session; user must confirm email before logging in. */
    suspend fun signup(username: String, password: String, email: String): Pair<User, String> {
        val resp = api.signup(SignupRequest(username, password, email.trim().lowercase()))
        val dto = resp.user ?: throw IllegalStateException("Signup response missing user")
        val msg = resp.message ?: "Check your email to confirm your account before logging in."
        return Pair(User(dto.id, dto.username, dto.createdAt), msg)
    }

    suspend fun login(username: String, password: String): com.maillardmap.domain.AuthResponse {
        val resp = api.login(LoginRequest(username, password))
        sessionManager.saveSession(resp.token, User(resp.user.id, resp.user.username, resp.user.createdAt))
        return com.maillardmap.domain.AuthResponse(
            User(resp.user.id, resp.user.username, resp.user.createdAt),
            resp.token,
        )
    }

    suspend fun resendConfirmation(usernameOrEmail: String): String {
        val r = api.resendConfirmation(ResendConfirmationRequest(usernameOrEmail.trim()))
        return r.message ?: "Check your email."
    }

    fun logout() = sessionManager.clearSession()
    fun isLoggedIn(): Boolean = sessionManager.isLoggedIn()
    fun currentUserId(): String? = sessionManager.getUserId()
    fun currentUsername(): String? = sessionManager.getUsername()

    // --- Users ---
    suspend fun getUser(id: String): User = api.getUser(id).toUser()
    suspend fun searchUsers(query: String): List<User> = api.searchUsers(query).map { it.toUser() }

    // --- Friends ---
    suspend fun sendFriendRequest(friendId: String) = api.sendFriendRequest(FriendRequestPayload(friendId))
    suspend fun acceptFriendRequest(friendId: String) = api.acceptFriendRequest(mapOf("friend_id" to friendId))
    suspend fun removeFriend(friendId: String) = api.removeFriend(friendId)
    suspend fun getFriends(): List<Friendship> = api.getFriendList().friends.map { it.toFriendship() }

    // --- Posts ---
    suspend fun createPost(
        foursquareId: String,
        comment: String?,
        photoUrls: List<String>,
        rating: Double
    ): Map<String, Any> {
        return api.createPost(CreatePostPayload(foursquareId, comment, photoUrls, rating))
    }

    suspend fun getFeed(): List<Post> = api.getFeed().posts.map { it.toPost() }
    suspend fun getUserPosts(userId: String): List<Post> = api.getUserPosts(userId).posts.map { it.toPost() }
    suspend fun likePost(postId: String): Map<String, Any> = api.likePost(postId)

    // --- Saved ---
    suspend fun savePlace(restaurantId: String): SavedPlace {
        return api.savePlace(SavePlacePayload(restaurantId)).toSavedPlace()
    }
    suspend fun getSavedPlaces(): List<SavedPlace> = api.getSavedPlaces().savedPlaces.map { it.toSavedPlace() }
    suspend fun deleteSavedPlace(restaurantId: String) = api.deleteSavedPlace(restaurantId)

    // --- Restaurants ---
    suspend fun searchRestaurants(query: String, lat: Double? = null, lng: Double? = null): List<Restaurant> {
        return api.searchRestaurants(query, lat, lng).map { it.toRestaurant() }
    }
    suspend fun getRestaurant(id: String): Restaurant = api.getRestaurant(id).toRestaurant()

    // --- Recommendations ---
    suspend fun blendTastes(userIds: List<String>): BlendResult {
        val resp = api.blendTastes(BlendPayload(userIds))
        return BlendResult(
            topCuisines = resp.topCuisines.map { CuisineCount(it.name, it.count) },
            centroid = resp.centroid?.let { LatLong(it.lat, it.lng) } ?: LatLong(0.0, 0.0),
            restaurants = resp.restaurants.map {
                ScoredRestaurant(
                    id = it.id,
                    foursquareId = it.foursquareId,
                    name = it.name,
                    cuisine = it.cuisine,
                    distance = it.distance,
                    score = it.score
                )
            }
        )
    }
}

// -- DTO -> Domain mappers --
private fun UserDTO.toUser() = User(id, username, createdAt, bio)
private fun FriendshipDTO.toFriendship() = Friendship(id, userId, friendId, friendUsername, status, createdAt, incomingPending)
private fun PostDTO.toPost() = Post(
    id = id,
    userId = userId,
    username = username,
    restaurantId = restaurantId,
    restaurantName = restaurantName,
    comment = comment,
    rating = rating,
    photos = photos?.map { it.toPhoto() } ?: emptyList(),
    lat = lat,
    lng = lng,
    liked = liked,
    likeCount = likeCount,
    createdAt = createdAt
)
private fun PostPhotoDTO.toPhoto() = PostPhoto(id ?: "", url, orderIndex)
private fun RestaurantDTO.toRestaurant() = Restaurant(id, foursquareId, name, lat, lng, cuisine)
private fun SavedPlaceDTO.toSavedPlace() = SavedPlace(id, restaurantId, restaurantName, savedAt)
