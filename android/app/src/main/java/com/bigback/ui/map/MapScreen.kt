package com.maillardmap.ui.map

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.material.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import com.maillardmap.common.PreviewTheme
import com.maillardmap.data.Repository
import com.maillardmap.domain.Post
import com.mapbox.geojson.Point
import com.mapbox.maps.CameraOptions
import com.mapbox.maps.MapInitOptions
import com.mapbox.maps.MapView
import com.mapbox.maps.Style

@Composable
fun MapScreen(
    repository: Repository
) {
    val context = LocalContext.current
    var hasLocationPermission by remember {
        mutableStateOf(
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
        )
    }
    var posts by remember { mutableStateOf<List<Post>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    var currentZoom by remember { mutableStateOf(11.0) }
    var error by remember { mutableStateOf<String?>(null) }

    val locationPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        hasLocationPermission = granted
    }

    LaunchedEffect(Unit) {
        if (!hasLocationPermission) {
            locationPermissionLauncher.launch(Manifest.permission.ACCESS_FINE_LOCATION)
        }
    }

    LaunchedEffect(Unit) {
        try {
            posts = repository.getFeed()
        } catch (e: Exception) {
            error = e.message ?: "Failed to load map data"
        } finally {
            isLoading = false
        }
    }

    PreviewTheme {
        Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text("Map") },
                    actions = {
                        Text(
                            text = if (currentZoom < 10.0) "Heatmap" else "Pins",
                            style = MaterialTheme.typography.body1
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                    }
                )
            }
        ) { padding ->
            if (isLoading) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
            } else if (error != null) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Text("Failed to load map data")
                }
            } else {
                Box(modifier = Modifier.padding(padding).fillMaxSize()) {
                    BigBackMapView(
                        context = context,
                        posts = posts,
                        isHeatmap = currentZoom < 10.0,
                        onCameraChange = { zoom ->
                            currentZoom = zoom
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun BigBackMapView(
    context: Context,
    posts: List<Post>,
    isHeatmap: Boolean,
    onCameraChange: (Double) -> Unit
) {
    AndroidView(
        modifier = Modifier.fillMaxSize(),
        factory = { ctx ->
            val mapView = MapView(ctx, MapInitOptions(ctx))
            val mapboxMap = mapView.getMapboxMap()

            mapboxMap.loadStyleUri(
                if (isHeatmap) Style.TRAFFIC_DAY else Style.MAPBOX_STREETS
            )

            mapboxMap.setCamera(
                CameraOptions.Builder()
                    .center(Point.fromLngLat(-122.4194, 37.7749))
                    .zoom(11.0)
                    .build()
            )

            mapView.gesturesPlugin.addOnCameraChangeListener { cameraChangedEventData ->
                onCameraChange(cameraChangedEventData.cameraState.zoom)
            }

            mapView
        },
        update = { mapView ->
            // Refresh annotations when posts change
        }
    )
}
