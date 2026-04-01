package com.bigback.ui.saved

import android.content.Context
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.material.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.bigback.common.PreviewTheme
import com.bigback.data.Repository
import com.bigback.domain.SavedPlace

@Composable
fun SavedPlacesScreen(
    repository: Repository
) {
    var savedPlaces by remember { mutableStateOf<List<SavedPlace>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(Unit) {
        try {
            savedPlaces = repository.getSavedPlaces()
        } catch (e: Exception) {
            error = e.message ?: "Failed to load saved places"
        } finally {
            isLoading = false
        }
    }

    PreviewTheme {
        Column(modifier = Modifier.fillMaxSize()) {
            Text(
                text = "Saved Places",
                style = MaterialTheme.typography.h6,
                modifier = Modifier.padding(16.dp)
            )

            Divider()

            if (isLoading) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = androidx.compose.ui.Alignment.Center) {
                    CircularProgressIndicator()
                }
            } else if (savedPlaces.isEmpty()) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = androidx.compose.ui.Alignment.Center) {
                    Text("No saved places yet")
                }
            } else {
                androidx.compose.foundation.lazy.LazyColumn(modifier = Modifier.weight(1f)) {
                    items(savedPlaces) { place ->
                        SavedPlaceItem(
                            place = place,
                            onDelete = {
                                repository.deleteSavedPlace(place.restaurantId)
                                savedPlaces = savedPlaces.filterNot { it.id == place.id }
                            }
                        )
                    }
                }
            }

            error?.let {
                Text(it, color = MaterialTheme.colors.error)
            }
        }
    }
}

@Composable
private fun SavedPlaceItem(
    place: SavedPlace,
    onDelete: () -> Unit
) {
    ListItem(
        text = { Text(place.restaurantName ?: "Restaurant") },
        secondaryText = { Text("Saved") },
        trailingIcon = {
            IconButton(onClick = onDelete) {
                Icon(Icons.Default.Delete, "Remove saved place")
            }
        },
        modifier = Modifier.clickable {
            // Navigate to restaurant info
        }
    )
    Divider()
}
