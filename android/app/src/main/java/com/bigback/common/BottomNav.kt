package com.maillardmap.common

import androidx.compose.material.BottomNavigation
import androidx.compose.material.BottomNavigationItem
import androidx.compose.material.Icon
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Group
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.Place

@Composable
fun BigBackBottomNav(
    currentRoute: String,
    onRouteClicked: (String) -> Unit
) {
    BottomNavigation {
        BottomNavigationItem(
            selected = currentRoute == "feed",
            onClick = { onRouteClicked("feed") },
            icon = { Icon(Icons.Default.Home, "Feed") },
            label = { Text("Feed") }
        )
        BottomNavigationItem(
            selected = currentRoute == "friends",
            onClick = { onRouteClicked("friends") },
            icon = { Icon(Icons.Default.Group, "Friends") },
            label = { Text("Friends") }
        )
        BottomNavigationItem(
            selected = currentRoute == "saved",
            onClick = { onRouteClicked("saved") },
            icon = { Icon(Icons.Default.Bookmark, "Saved") },
            label = { Text("Saved") }
        )
        BottomNavigationItem(
            selected = currentRoute == "map",
            onClick = { onRouteClicked("map") },
            icon = { Icon(Icons.Default.Place, "Map") },
            label = { Text("Map") }
        )
    }
}
