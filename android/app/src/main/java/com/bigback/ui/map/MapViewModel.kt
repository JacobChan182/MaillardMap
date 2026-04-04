package com.maillardmap.ui.map

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Color
import androidx.core.content.ContextCompat
import androidx.lifecycle.ViewModel
import com.maillardmap.data.Repository
import com.maillardmap.domain.Post
import com.maillardmap.domain.Restaurant
import com.mapbox.geojson.Feature
import com.mapbox.geojson.FeatureCollection
import com.mapbox.geojson.Point
import com.mapbox.maps.MapView
import com.mapbox.maps.Style
import com.mapbox.maps.extension.compose.MapboxMap
import com.mapbox.maps.extension.compose.animation.viewport.rememberMapViewportState
import com.mapbox.maps.extension.compose.generated.*
import com.mapbox.maps.extension.style.layers.generated.*
import com.mapbox.maps.extension.style.layers.properties.generated.Projection
import com.mapbox.maps.extension.style.sources.generated.GeoJsonSource
import com.mapbox.maps.plugin.gestures.OnMapClickListener
import com.mapbox.maps.plugin.locationcomponent.OnIndicatorPositionChangedListener
import com.mapbox.maps.plugin.locationcomponent.location
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.MainScope

class MapViewModel(
    private val repository: Repository,
    private val context: Context
) : ViewModel() {

    companion object {
        // Matches iOS exactly: span < 0.01 shows pins, span >= 0.01 shows heatmap
        const val ZOOM_THRESHOLD: Double = 0.01

        // Mapbox style constants
        private const val HEATMAP_LAYER_ID = "heatmap-layer"
        private const val HEATMAP_SOURCE_ID = "heatmap-source"
        private const val PINS_LAYER_ID = "pins-layer"
        private const val PINS_SOURCE_ID = "pins-source"
    }

    private val scope = CoroutineScope(MainScope().coroutineContext)

    val posts = mutableStateOf<List<Post>>(emptyList())
    val isLoading = mutableStateOf(false)
    val errorMessage = mutableStateOf<String?>(null)

    // Span that matches iOS coordinate span (latitudeDelta)
    val currentSpan = mutableStateOf(0.05) // Default from iOS (0.05)

    // Heatmap and pin visibility states
    val showHeatmap = mutableStateOf(true)
    val showPins = mutableStateOf(false)

    // Restaurant callout card state
    val restaurantCallout = mutableStateOf<RestaurantCallout?>(null)
    val calloutJustShown = mutableStateOf(false) // Prevents immediate dismissal after programmatic movement

    // User location
    val userLocation = mutableStateOf<android.location.Location?>(null)

    // Dismissal tracking (matches iOS MapViewModel logic)
    private var calloutDismissRegionAnchor: Double? = null
    private var calloutDismissSkipCameraEndsRemaining = 0
    private var calloutDelayedDismissJob: Job? = null
    private var calloutDismissAlignJob: Job? = null

    private var hasCenteredOnUserLocation = false

    init {
        requestLocationPermission()
        loadPosts()
    }

    private fun requestLocationPermission() {
        val fineGranted = ContextCompat.checkSelfPermission(
            context, Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        val coarseGranted = ContextCompat.checkSelfPermission(
            context, Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        // If not granted, will need to be requested from Activity/Fragment
    }

    fun onUserLocationUpdated(location: android.location.Location) {
        if (!hasCenteredOnUserLocation) {
            hasCenteredOnUserLocation = true
        }
        userLocation.value = location
    }

    /**
     * Called when map camera movement ends.
     * @param span The latitude span (matches iOS MKCoordinateRegion.span.latitudeDelta)
     */
    fun onRegionChange(span: Double) {
        currentSpan.value = span
        val shouldShowHeatmap = span > ZOOM_THRESHOLD
        showHeatmap.value = shouldShowHeatmap
        showPins.value = !shouldShowHeatmap

        // Update map layers should happen in UI, but we trigger re-evaluation of annotations here
        updateAnnotationsForCurrentState()

        // Handle callout dismissal like iOS
        if (restaurantCallout.value != null) {
            onMapCameraChangeEnded(span)
        }
    }

    fun loadPosts() {
        scope.launch {
            isLoading.value = true
            try {
                val feedPosts = repository.getFeed()
                posts.value = feedPosts
                updateAnnotationsForCurrentState()
            } catch (e: Exception) {
                errorMessage.value = e.message ?: "Failed to load map data"
            } finally {
                isLoading.value = false
            }
        }
    }

    /**
     * Focus map on restaurant from a post chip in the feed.
     * Shows callout card and optionally uses temporary gray pin.
     */
    fun focusRestaurantFromPost(
        post: Post,
        onCameraMove: (lat: Double, lng: Double, zoom: Double) -> Unit
    ) {
        calloutInterruptedDismissTasks()

        val lat = post.lat ?: return
        val lng = post.lng ?: return

        restaurantCallout.value = RestaurantCallout(
            restaurantId = post.restaurantId,
            name = post.restaurantName ?: "Unknown",
            address = post.restaurantAddress?.trim()?.takeIf { it.isNotEmpty() },
            lat = lat,
            lng = lng,
            useTemporaryGrayPin = false
        )

        // iOS uses span 0.045 when focusing
        val span = 0.045
        currentSpan.value = span
        showHeatmap.value = span > ZOOM_THRESHOLD
        showPins.value = !showHeatmap.value

        calloutDismissRegionAnchor = span
        calloutDismissSkipCameraEndsRemaining = 3
        calloutJustShown.value = true // Prevent immediate dismissal

        // Enrich address if empty
        if (restaurantCallout.value.address.isNullOrEmpty()) {
            scope.launch {
                try {
                    val restaurant = repository.getRestaurant(post.restaurantId)
                    if (restaurant.address != null) {
                        restaurantCallout.value = restaurantCallout.value?.copy(address = restaurant.address)
                    }
                } catch (e: Exception) {
                    // silently fail
                }
            }
        }

        updateAnnotationsForCurrentState()
        onCameraMove(lat, lng, 12.0) // Zoom level that roughly corresponds to span 0.045

        // Schedule alignment task like iOS (600ms)
        scheduleCalloutDismissAlignLikeMapPin(post.restaurantId)
    }

    /**
     * Focus map from restaurant search result.
     * Shows gray pin if there are no posts at the venue yet.
     */
    fun focusRestaurantFromSearch(
        restaurant: Restaurant,
        onCameraMove: (lat: Double, lng: Double, zoom: Double) -> Unit
    ) {
        calloutInterruptedDismissTasks()

        restaurantCallout.value = RestaurantCallout(
            restaurantId = restaurant.id,
            name = restaurant.name,
            address = restaurant.address?.trim()?.takeIf { it.isNotEmpty() },
            lat = restaurant.lat,
            lng = restaurant.lng,
            useTemporaryGrayPin = true // Start with gray; will update after feed check
        )

        val span = 0.045
        currentSpan.value = span
        showHeatmap.value = span > ZOOM_THRESHOLD
        showPins.value = !showHeatmap.value

        calloutDismissRegionAnchor = span
        calloutDismissSkipCameraEndsRemaining = 3
        calloutJustShown.value = true

        onCameraMove(restaurant.lat, restaurant.lng, 12.0)

        // Check if there are posts at this venue
        scope.launch {
            try {
                val posts = repository.getUserPosts(restaurant.id)
                val hasPosts = posts.isNotEmpty()
                // Update gray pin status
                val current = restaurantCallout.value
                if (current != null && current.restaurantId == restaurant.id) {
                    restaurantCallout.value = current.copy(useTemporaryGrayPin = !hasPosts)
                }
                scheduleCalloutDismissAlignLikeMapPin(restaurant.id)
            } catch (e: Exception) {
                // silently fail, keep gray pin
                scheduleCalloutDismissAlignLikeMapPin(restaurant.id)
            }
        }

        updateAnnotationsForCurrentState()
    }

    /**
     * Show callout when user taps a pin on the map.
     */
    fun showCalloutForMapPin(
        restaurantId: String,
        name: String,
        lat: Double,
        lng: Double,
        onCameraMove: (lat: Double, lng: Double, zoom: Double) -> Unit
    ) {
        calloutInterruptedDismissTasks()

        restaurantCallout.value = RestaurantCallout(
            restaurantId = restaurantId,
            name = name,
            lat = lat,
            lng = lng,
            useTemporaryGrayPin = false
        )

        calloutDismissRegionAnchor = currentSpan.value
        calloutDismissSkipCameraEndsRemaining = 0
        calloutJustShown.value = true

        updateAnnotationsForCurrentState()

        // Enrich address
        scope.launch {
            try {
                val restaurant = repository.getRestaurant(restaurantId)
                val addr = restaurant.address
                if (!addr.isNullOrEmpty()) {
                    restaurantCallout.value = restaurantCallout.value?.copy(address = addr)
                }
            } catch (e: Exception) {
                // silently fail
            }
        }
    }

    fun clearRestaurantCallout() {
        calloutInterruptedDismissTasks()
        restaurantCallout.value = null
        calloutDismissRegionAnchor = null
        calloutDismissSkipCameraEndsRemaining = 0
        updateAnnotationsForCurrentState()
    }

    private fun calloutInterruptedDismissTasks() {
        calloutDelayedDismissJob?.cancel()
        calloutDelayedDismissJob = null
        calloutDismissAlignJob?.cancel()
        calloutDismissAlignJob = null
    }

    /**
     * After programmatic camera moves, Mapbox emits extra onCameraChange callbacks.
     * Match iOS behavior to not dismiss callout immediately.
     */
    private fun scheduleCalloutDismissAlignLikeMapPin(restaurantId: String) {
        calloutDismissAlignJob?.cancel()
        calloutDismissAlignJob = scope.launch {
            delay(600) // 600ms matches iOS
            val current = restaurantCallout.value
            if (current != null && current.restaurantId == restaurantId) {
                calloutDismissRegionAnchor = currentSpan.value
                calloutDismissSkipCameraEndsRemaining = 0
                calloutJustShown.value = false
            }
        }
    }

    private fun onMapCameraChangeEnded(span: Double) {
        val callout = restaurantCallout.value ?: return

        if (calloutDismissSkipCameraEndsRemaining > 0) {
            calloutDismissSkipCameraEndsRemaining--
            calloutDismissRegionAnchor = span
            calloutDelayedDismissJob?.cancel()
            return
        }

        val anchor = calloutDismissRegionAnchor ?: return

        if (regionsMatchForCalloutDismiss(anchor, span)) {
            calloutDismissRegionAnchor = span
            calloutDelayedDismissJob?.cancel()
            return
        }

        // User moved map significantly - dismiss after 100ms delay (matches iOS)
        val rid = callout.restaurantId
        calloutDelayedDismissJob?.cancel()
        calloutDelayedDismissJob = scope.launch {
            delay(100)
            val current = restaurantCallout.value
            if (current != null && current.restaurantId == rid) {
                clearRestaurantCallout()
            }
        }
    }

    /**
     * Check if two regions are "close enough" to not trigger dismissal.
     * iOS uses: lat/lon diff < 0.001, span diff < 0.012
     */
    private fun regionsMatchForCalloutDismiss(anchor: Double, current: Double): Boolean {
        return Math.abs(anchor - current) < 0.0012
    }

    fun getHeatmapPoints(): List<Point> {
        if (!showHeatmap.value) return emptyList()
        return posts.value
            .filter { it.lat != null && it.lng != null }
            .map { Point.fromLngLat(it.lng!!, it.lat!!) }
    }

    fun getPinPosts(): List<Post> {
        if (!showPins.value) return emptyList()
        return posts.value.filter { it.lat != null && it.lng != null }
    }

    private fun updateAnnotationsForCurrentState() {
        // No-op if using declarative layer rendering in UI
        // But we could trigger side effects here if needed
    }

    override fun onCleared() {
        super.onCleared()
        scope.cancel()
    }
}

data class RestaurantCallout(
    val restaurantId: String,
    val name: String,
    val address: String? = null,
    val lat: Double,
    val lng: Double,
    val useTemporaryGrayPin: Boolean = false
)
