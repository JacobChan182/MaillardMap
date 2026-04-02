package com.bigback.data

import com.bigback.domain.*
import com.google.gson.GsonBuilder
import com.google.gson.annotations.SerializedName
import okhttp3.Interceptor
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import retrofit2.http.*
import java.util.concurrent.TimeUnit

// -- Request DTOs --

data class SignupRequest(
    val username: String,
    val password: String
)

data class LoginRequest(
    val username: String,
    val password: String
)

data class FriendRequestPayload(
    val friend_id: String
)

data class CreatePostPayload(
    @SerializedName("foursquare_id") val foursquareId: String,
    val comment: String? = null,
    @SerializedName("photo_urls") val photoUrls: List<String> = emptyList(),
    val rating: Double
)

data class SavePlacePayload(
    @SerializedName("restaurant_id") val restaurantId: String
)

data class BlendPayload(
    @SerializedName("user_ids") val userIds: List<String>
)

// -- Response DTOs --

data class UserDTO(
    val id: String,
    val username: String,
    @SerializedName("created_at") val createdAt: String? = null,
    val bio: String? = null
)

data class AuthResponse(
    val ok: Boolean = true,
    val token: String,
    val user: UserDTO
)

data class PostDTO(
    val id: String,
    @SerializedName("user_id") val userId: String,
    val username: String? = null,
    @SerializedName("restaurant_id") val restaurantId: String,
    @SerializedName("restaurant_name") val restaurantName: String? = null,
    val comment: String? = null,
    val rating: Double? = null,
    val photos: List<PostPhotoDTO>? = emptyList(),
    val lat: Double? = null,
    val lng: Double? = null,
    val liked: Boolean = false,
    @SerializedName("like_count") val likeCount: Int = 0,
    @SerializedName("created_at") val createdAt: String
)

data class PostPhotoDTO(
    val id: String? = null,
    val url: String,
    @SerializedName("order_index") val orderIndex: Int
)

data class RestaurantDTO(
    val id: String,
    @SerializedName("foursquare_id") val foursquareId: String,
    val name: String,
    val lat: Double,
    val lng: Double,
    val cuisine: String? = null
)

data class SavedPlaceDTO(
    val id: String,
    @SerializedName("restaurant_id") val restaurantId: String,
    @SerializedName("restaurant_name") val restaurantName: String? = null,
    @SerializedName("saved_at") val savedAt: String
)

data class FriendshipDTO(
    val id: String,
    @SerializedName("user_id") val userId: String = "",
    @SerializedName("friend_id") val friendId: String,
    @SerializedName("friend_username") val friendUsername: String? = null,
    val status: String,
    @SerializedName("created_at") val createdAt: String,
    val incomingPending: Boolean? = null
)

data class CuisineCountDTO(
    val name: String,
    val count: Int
)

data class CentroidDTO(
    val lat: Double,
    val lng: Double
)

data class ScoredRestaurantDTO(
    val id: String,
    @SerializedName("foursquare_id") val foursquareId: String,
    val name: String,
    val cuisine: String? = null,
    val distance: Double,
    val score: Double
)

data class BlendResponseDTO(
    @SerializedName("top_cuisines") val topCuisines: List<CuisineCountDTO> = emptyList(),
    val centroid: CentroidDTO? = null,
    val restaurants: List<ScoredRestaurantDTO> = emptyList()
)

data class HealthDTO(
    val ok: Boolean,
    val service: String? = null,
    val time: String? = null
)

// Wrapper for paginated responses
data class PostsListResponse(
    val posts: List<PostDTO> = emptyList()
)

data class SavedPlacesResponse(
    @SerializedName("saved_places") val savedPlaces: List<SavedPlaceDTO> = emptyList()
)

data class FriendsListResponse(
    val friends: List<FriendshipDTO> = emptyList()
)

// -- Retrofit API interface --

interface BigBackApi {

    // Auth
    @POST("auth/signup")
    suspend fun signup(@Body body: SignupRequest): AuthResponse

    @POST("auth/login")
    suspend fun login(@Body body: LoginRequest): AuthResponse

    // Users
    @GET("users/{id}")
    suspend fun getUser(@Path("id") id: String): UserDTO

    @GET("users/search")
    suspend fun searchUsers(@Query("q") q: String): List<UserDTO>

    // Friends
    @POST("friends/request")
    suspend fun sendFriendRequest(
        @Body body: FriendRequestPayload
    ): Map<String, Boolean>

    @POST("friends/accept")
    suspend fun acceptFriendRequest(
        @Body body: Map<String, String>
    ): Map<String, Boolean>

    @GET("friends/list")
    suspend fun getFriendList(): FriendsListResponse

    @DELETE("friends/{id}")
    suspend fun removeFriend(@Path("id") friendId: String): Map<String, Boolean>

    // Posts
    @POST("posts")
    suspend fun createPost(@Body body: CreatePostPayload): Map<String, Any>

    @GET("posts/feed")
    suspend fun getFeed(): PostsListResponse

    @GET("posts/user/{id}")
    suspend fun getUserPosts(@Path("id") userId: String): PostsListResponse

    @POST("posts/{id}/like")
    suspend fun likePost(@Path("id") postId: String): Map<String, Any>

    // Saved
    @POST("saved")
    suspend fun savePlace(@Body body: SavePlacePayload): SavedPlaceDTO

    @GET("saved")
    suspend fun getSavedPlaces(): SavedPlacesResponse

    @DELETE("saved/{restaurant_id}")
    suspend fun deleteSavedPlace(@Path("restaurant_id") restaurantId: String): Map<String, Boolean>

    // Restaurants
    @GET("restaurants/search")
    suspend fun searchRestaurants(
        @Query("q") q: String,
        @Query("lat") lat: Double? = null,
        @Query("lng") lng: Double? = null
    ): List<RestaurantDTO>

    @GET("restaurants/{id}")
    suspend fun getRestaurant(@Path("id") id: String): RestaurantDTO

    // Recommendations
    @POST("recommendations/blend")
    suspend fun blendTastes(@Body body: BlendPayload): BlendResponseDTO
}

// -- Retrofit client factory --

object RetrofitClient {

    fun create(
        client: OkHttpClient,
        baseUrl: String,
    ): BigBackApi {
        val gson = GsonBuilder()
            .setLenient()
            .create()

        return Retrofit.Builder()
            .baseUrl(baseUrl)
            .client(client)
            .addConverterFactory(GsonConverterFactory.create(gson))
            .build()
            .create(BigBackApi::class.java)
    }

    fun okHttpClient(sessionManager: SessionManager): OkHttpClient {
        val logging = HttpLoggingInterceptor().apply {
            level = HttpLoggingInterceptor.Level.BODY
        }

        val authInterceptor = Interceptor { chain ->
            val token = sessionManager.getToken()
            val request = chain.request().newBuilder().apply {
                addHeader("Content-Type", "application/json")
                if (token != null) {
                    addHeader("Authorization", "Bearer $token")
                }
            }.build()
            chain.proceed(request)
        }

        return OkHttpClient.Builder()
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(15, TimeUnit.SECONDS)
            .writeTimeout(15, TimeUnit.SECONDS)
            .addInterceptor(authInterceptor)
            .addInterceptor(logging)
            .build()
    }
}
