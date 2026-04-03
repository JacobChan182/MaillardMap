package com.maillardmap.ui.map

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.material.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.maillardmap.common.PreviewTheme
import com.maillardmap.data.Repository
import com.mapbox.geojson.Point
import com.mapbox.maps.Style
import com.mapbox.maps.extension.compose.ComposeMapInitOptions
import com.mapbox.maps.extension.compose.MapEffect
import com.mapbox.maps.extension.compose.MapboxMap
import com.mapbox.maps.extension.compose.animation.viewport.rememberMapViewportState
import com.mapbox.maps.extension.compose.style.MapStyle

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
            repository.getFeed()
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
                    val viewport = rememberMapViewportState {
                        setCameraOptions {
                            center(Point.fromLngLat(-122.4194, 37.7749))
                            zoom(11.0)
                        }
                    }
                    val composeMapInitOptions = with(LocalDensity.current) {
                        remember(density) {
                            ComposeMapInitOptions(pixelRatio = density, textureView = true)
                        }
                    }
                    MapboxMap(
                        modifier = Modifier.fillMaxSize(),
                        composeMapInitOptions = composeMapInitOptions,
                        mapViewportState = viewport,
                        style = {
                            MapStyle(style = Style.MAPBOX_STREETS)
                        },
                    ) {
                        MapEffect(Unit) { mapView ->
                            mapView.mapboxMap.addOnCameraChangeListener {
                                currentZoom = mapView.mapboxMap.cameraState.zoom
                            }
                        }
                    }
                }
            }
        }
    }
}
