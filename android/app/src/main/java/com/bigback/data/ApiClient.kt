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

// -- DTOs --

data class UserDTO(
    val id: String,
    val username: String,
    @SerializedName("phone_or_email") val phoneOrEmail: String? = null,
    @SerializedName("created_at") val createdAt: String?
)

data class LoginRequest(
    @SerializedName("phone_or_email") val phoneOrEmail: String,
    val password: String
)
data class SignupRequest(
    val username: String,
    @SerializedName("phone_or_email") val phoneOrEmail: String,
    val password: String
)

data class AuthResponse(
    val user: UserDTO,
    val token: String
)

data class FriendshipDTO(
    val id: String,
    @SerializedName("user_id") val userId: String,
    @SerializedName("friend_id") val friendId: String,
    val friendUsername: String? = null,
    val status: String,
    @SerializedName("created_at") val createdAt: String
)

data class FriendRequestPayload(
    @SerializedName("friend_username") val friendUsername: String
)

data class RestaurantDTO(
    val id: String? = null,
    val foursquareId: String? = null,
    @SerializedName("foursquare_id") val fsqId: String? = null,
    val name: String,
    val lat: Double,
    val lng: Double,
    val cuisine: String?
)

fun RestaurantDTO.toDomain(): Restaurant = Restaurant(
    id = id ?: fsqId ?: "",
    foursquareId = fsqId ?: foursquareId ?: "",
    name = name,
    lat = lat,
    lng = lng,
    cuisine = cuisine
)

data class PostDTO(
    val id: String,
    @SerializedName("user_id") val userId: String,
    val username: String? = null,
    @SerializedName("restaurant_id") val restaurantId: String,
    @SerializedName("restaurant_name") val restaurantName: String? = null,
    val comment: String? = null,
    val photos: List<PostPhotoDTO>? = null,
    val lat: Double? = null,
    val lng: Double? = null,
    @SerializedName("is_liked") val isLiked: Boolean = false,
    @SerializedName("like_count") val likeCount: Int = 0,
    @SerializedName("created_at") val createdAt: String
)

fun PostDTO.toDomain(): Post = Post(
    id = id,
    userId = userId,
    username = username,
    restaurantId = restaurantId,
    restaurantName = restaurantName,
    comment = comment,
    photos = (photos ?: emptyList()).map { it.toDomain() },
    latitude = lat,
    longitude = lng,
    isLiked = isLiked,
    likeCount = likeCount,
    createdAt = createdAt
)

data class PostPhotoDTO(
    val id: String? = null,
    val url: String,
    @SerializedName("order_index") val orderIndex: Int
)

fun PostPhotoDTO.toDomain(): PostPhoto = PostPhoto(
    id = id,
    url = url,
    orderIndex = orderIndex
)

data class CreatePostPayload(
    @SerializedName("restaurant_id") val restaurantId: String,
    val comment: String?,
    @SerializedName("photo_urls") val photoUrls: List<String>
)

data class LikedDTO(
    val id: String,
    @SerializedName("user_id") val userId: String,
    @SerializedName("post_id") val postId: String,
    @SerializedName("created_at") val createdAt: String
)

data class SavedPlaceDTO(
    val id: String,
    @SerializedName("restaurant_id") val restaurantId: String,
    @SerializedName("restaurant_name") val restaurantName: String? = null,
    @SerializedName("created_at") val createdAt: String
)

fun SavedPlaceDTO.toDomain(): SavedPlace = SavedPlace(
    id = id,
    restaurantId = restaurantId,
    restaurantName = restaurantName,
    createdAt = createdAt
)

data class SavePlacePayload(
    @SerializedName("restaurant_id") val restaurantId: String
)

data class BlendPayload(
    @SerializedName("user_ids") val userIds: List<String>
)

data class BlendResponseDTO(
    val restaurants: List<RestaurantRecommendationDTO>
)

data class RestaurantRecommendationDTO(
    val id: String,
    val name: String,
    val lat: Double,
    val lng: Double,
    val cuisine: String?,
    val score: Int
)

fun RestaurantRecommendationDTO.toDomain(): RestaurantRecommendation = RestaurantRecommendation(
    id = id,
    name = name,
    lat = lat,
    lng = lng,
    cuisine = cuisine,
    score = score
)

data class HealthDTO(
    val ok: Boolean,
    val service: String,
    val time: String?
)

// -- Retrofit interface --

interface BigBackApi {

    // Auth
    @POST("auth/signup")
    suspend fun signup(@Body request: SignupRequest): AuthResponse

    @POST("auth/login")
    suspend fun login(@Body request: LoginRequest): AuthResponse

    // Users
    @GET("users/{id}")
    suspend fun getUser(@Path("id") id: String): UserDTO

    @GET("users/search")
    suspend fun searchUsers(@Query("q") query: String): List<UserDTO>

    // Friends
    @POST("friends/request")
    suspend fun requestFriend(@Body payload: FriendRequestPayload): FriendshipDTO

    @POST("friends/accept")
    suspend fun acceptFriend(
        @Body payload: @JvmSuppressWildcards Map<String, String>
    ): FriendshipDTO

    @GET("friends/list")
    suspend fun getFriends(): List<FriendshipDTO>

    // Posts
    @POST("posts")
    suspend fun createPost(@Body payload: CreatePostPayload): PostDTO

    @GET("posts/feed")
    suspend fun getFeed(@Query("page") page: Int = 1, @Query("limit") limit: Int = 30): List<PostDTO>

    @GET("posts/user/{id}")
    suspend fun getUserPosts(@Path("id") userId: String): List<PostDTO>

    @POST("posts/{id}/like")
    suspend fun toggleLike(@Path("id") postId: String): LikedDTO

    // Saved places
    @POST("saved")
    suspend fun savePlace(@Body payload: SavePlacePayload): SavedPlaceDTO

    @GET("saved")
    suspend fun getSavedPlaces(): List<SavedPlaceDTO>

    @DELETE("saved/{restaurant_id}")
    suspend fun deleteSavedPlace(@Path("restaurant_id") restaurantId: String)

    // Restaurants
    @GET("restaurants/search")
    suspend fun searchRestaurants(@Query("q") query: String): List<RestaurantDTO>

    @GET("restaurants/{id}")
    suspend fun getRestaurant(@Path("id") id: String): RestaurantDTO

    // Recommendations
    @POST("recommendations/blend")
    suspend fun blendTastes(@Body payload: BlendPayload): BlendResponseDTO

    // Health
    @GET("health")
    suspend fun health(): HealthDTO
}

object RetrofitClient {

    private val gson = GsonBuilder()
        .setLenient()
        .create()

    fun create(client: OkHttpClient, baseUrl: String): BigBackApi {
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
            val requestBuilder = chain.request().newBuilder()
            if (token != null) {
                requestBuilder.addHeader("Authorization", "Bearer $token")
            }
            chain.proceed(requestBuilder.build())
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
