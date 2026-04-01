package com.bigback.data

import com.bigback.domain.*

/**
 * Repository that wraps API calls and handles token/session management.
 */
class Repository(
    private val api: BigBackApi,
    private val sessionManager: SessionManager
) {

    // --- Auth ---
    suspend fun signup(username: String, phoneOrEmail: String, password: String): AuthResponse {
        return api.signup(SignupRequest(username, phoneOrEmail, password)).also { response ->
            sessionManager.saveSession(response.token, response.user.toDomain())
        }
    }

    suspend fun login(phoneOrEmail: String, password: String): AuthResponse {
        return api.login(LoginRequest(phoneOrEmail, password)).also { response ->
            sessionManager.saveSession(response.token, response.user.toDomain())
        }
    }

    fun logout() {
        sessionManager.clearSession()
    }

    fun isLoggedIn(): Boolean = sessionManager.isLoggedIn()
    fun currentUserId(): String? = sessionManager.getUserId()
    fun currentUsername(): String? = sessionManager.getUsername()

    // --- Users ---
    suspend fun getUser(id: String): User {
        return api.getUser(id).toDomain()
    }

    suspend fun searchUsers(query: String): List<User> {
        return api.searchUsers(query).map { it.toDomain() }
    }

    // --- Friends ---
    suspend fun requestFriend(username: String): Friendship {
        return api.requestFriend(FriendRequestPayload(username)).toDomain()
    }

    suspend fun acceptFriend(friendId: String): Friendship {
        return api.acceptFriend(mapOf("friend_id" to friendId)).toDomain()
    }

    suspend fun getFriends(): List<Friendship> {
        return api.getFriends().map { it.toDomain() }
    }

    // --- Posts ---
    suspend fun createPost(post: CreatePostRequest): Post {
        return api.createPost(
            CreatePostPayload(post.restaurantId, post.comment, post.photoUrls)
        ).toDomain()
    }

    suspend fun getFeed(page: Int = 1, limit: Int = 30): List<Post> {
        return api.getFeed(page, limit).map { it.toDomain() }
    }

    suspend fun getUserPosts(userId: String): List<Post> {
        return api.getUserPosts(userId).map { it.toDomain() }
    }

    suspend fun toggleLike(postId: String) {
        api.toggleLike(postId)
    }

    // --- Saved places ---
    suspend fun savePlace(restaurantId: String): SavedPlace {
        return api.savePlace(SavePlacePayload(restaurantId)).toDomain()
    }

    suspend fun getSavedPlaces(): List<SavedPlace> {
        return api.getSavedPlaces().map { it.toDomain() }
    }

    suspend fun deleteSavedPlace(restaurantId: String) {
        api.deleteSavedPlace(restaurantId)
    }

    // --- Restaurants ---
    suspend fun searchRestaurants(query: String): List<Restaurant> {
        return api.searchRestaurants(query).map { it.toDomain() }
    }

    suspend fun getRestaurant(id: String): Restaurant {
        return api.getRestaurant(id).toDomain()
    }

    // --- Recommendations ---
    suspend fun blendTastes(userIds: List<String>): List<RestaurantRecommendation> {
        return api.blendTastes(BlendPayload(userIds)).restaurants.map { it.toDomain() }
    }

    // --- Health ---
    suspend fun health(): Health {
        return api.health().run { Health(ok, service, time) }
    }
}

private fun com.bigback.data.UserDTO.toDomain() =
    com.bigback.domain.User(id, username, createdAt)

private fun com.bigback.data.FriendshipDTO.toDomain() =
    Friendship(id, userId, friendId, friendUsername, status, createdAt)
