package com.bigback.domain

import java.util.UUID

// -- Pure domain models, no serialization --

data class User(
    val id: String = UUID.randomUUID().toString(),
    val username: String,
    val createdAt: String? = null
)

enum class FriendshipStatus {
    accepted, pending
}

data class Friendship(
    val id: String,
    val userId: String,
    val friendId: String,
    val friendUsername: String? = null,
    val status: String,
    val createdAt: String
) {
    val statusEnum: FriendshipStatus?
        get() = runCatching { FriendshipStatus.valueOf(status) }.getOrNull()
}

data class FriendshipRequest(val friendId: String)

data class Restaurant(
    val id: String,
    val foursquareId: String,
    val name: String,
    val lat: Double,
    val lng: Double,
    val cuisine: String? = null
)

data class Post(
    val id: String,
    val userId: String,
    val username: String? = null,
    val restaurantId: String,
    val restaurantName: String? = null,
    val comment: String? = null,
    val photos: List<PostPhoto> = emptyList(),
    val latitude: Double? = null,
    val longitude: Double? = null,
    val isLiked: Boolean = false,
    val likeCount: Int = 0,
    val createdAt: String
)

data class PostPhoto(
    val id: String? = null,
    val url: String,
    val orderIndex: Int
)

data class CreatePostRequest(
    val restaurantId: String,
    val comment: String?,
    val photoUrls: List<String>
)

data class Like(
    val id: String,
    val userId: String,
    val postId: String,
    val createdAt: String
)

data class SavedPlace(
    val id: String,
    val restaurantId: String,
    val restaurantName: String? = null,
    val createdAt: String
)

data class SavePlaceRequest(val restaurantId: String)

data class RestaurantRecommendation(
    val id: String,
    val name: String,
    val lat: Double,
    val lng: Double,
    val cuisine: String?,
    val score: Int
)

data class Health(
    val ok: Boolean,
    val service: String,
    val time: String?
)

data class AuthResponse(
    val user: User,
    val token: String
)

data class FoursquareVenue(
    val id: String,
    val name: String,
    val lat: Double,
    val lng: Double,
    val categories: List<String>? = null
)
