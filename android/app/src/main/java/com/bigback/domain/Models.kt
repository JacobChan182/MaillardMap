package com.bigback.domain

data class User(
    val id: String,
    val username: String,
    val createdAt: String? = null
)

enum class FriendshipStatus { accepted, pending }

data class Friendship(
    val id: String,
    val userId: String,
    val friendId: String,
    val friendUsername: String? = null,
    val status: String,
    val createdAt: String
)

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
    val lat: Double? = null,
    val lng: Double? = null,
    val liked: Boolean = false,
    val likeCount: Int = 0,
    val createdAt: String
)

data class PostPhoto(
    val id: String,
    val url: String,
    val orderIndex: Int
)

data class SavedPlace(
    val id: String,
    val restaurantId: String,
    val restaurantName: String? = null,
    val savedAt: String
)

data class CuisineCount(val name: String, val count: Int)
data class LatLong(val lat: Double, val lng: Double)
data class ScoredRestaurant(
    val id: String,
    val foursquareId: String,
    val name: String,
    val cuisine: String? = null,
    val distance: Double,
    val score: Double
)
data class BlendResult(
    val topCuisines: List<CuisineCount>,
    val centroid: LatLong,
    val restaurants: List<ScoredRestaurant>
)

data class AuthResponse(val user: User, val token: String)
data class Health(val ok: Boolean, val service: String? = null, val time: String? = null)
