package com.bigback.ui.blend

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.bigback.common.PreviewTheme
import com.bigback.data.Repository
import com.bigback.domain.Friendship
import com.bigback.domain.ScoredRestaurant

@Composable
fun BlendScreen(
    repository: Repository,
    currentUserId: String,
    onNavigateBack: () -> Unit
) {
    var friends by remember { mutableStateOf<List<Friendship>>(emptyList()) }
    var selectedFriends by remember { mutableStateOf<Set<String>>(emptySet()) }
    var recommendations by remember { mutableStateOf<List<ScoredRestaurant>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    var blendLoading by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(Unit) {
        try {
            friends = repository.getFriends().filter { it.status == "accepted" }
        } catch (e: Exception) {
            error = "Failed to load friends"
        } finally {
            isLoading = false
        }
    }

    PreviewTheme {
        Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text("Blend Tastes") },
                    navigationIcon = {
                        IconButton(onClick = onNavigateBack) {
                            Icon(Icons.Default.ArrowBack, "Back")
                        }
                    }
                )
            }
        ) { padding ->
            Column(
                modifier = Modifier.padding(padding).padding(16.dp)
            ) {
                Text(
                    "Select friends to blend tastes with",
                    style = MaterialTheme.typography.subtitle1
                )

                Spacer(modifier = Modifier.height(12.dp))

                if (isLoading) {
                    Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                } else if (friends.isEmpty()) {
                    Text("No friends to blend with yet")
                } else {
                    LazyColumn(modifier = Modifier.weight(1f)) {
                        items(friends) { friendship ->
                            val userId = friendship.friendId
                            val username = friendship.friendUsername ?: userId
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable {
                                        val mutable = selectedFriends.toMutableSet()
                                        if (userId in mutable) {
                                            mutable.remove(userId)
                                        } else {
                                            mutable.add(userId)
                                        }
                                        selectedFriends = mutable
                                    }
                                    .padding(vertical = 8.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Checkbox(
                                    checked = userId in selectedFriends,
                                    onCheckedChange = null
                                )
                                Text(username, modifier = Modifier.padding(start = 8.dp))
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(24.dp))

                Button(
                    onClick = {
                        if (selectedFriends.isEmpty()) {
                            error = "Select at least one friend"
                            return@Button
                        }
                        blendLoading = true
                        error = null
                        val scope = rememberCoroutineScope()
                        scope.launch {
                            try {
                                val userIds = listOf(currentUserId) + selectedFriends
                                recommendations = repository.blendTastes(userIds)
                            } catch (e: Exception) {
                                error = e.message ?: "Blend failed"
                            } finally {
                                blendLoading = false
                            }
                        }
                    },
                    modifier = Modifier.fillMaxWidth(),
                    enabled = selectedFriends.isNotEmpty() && !blendLoading
                ) {
                    if (blendLoading) {
                        CircularProgressIndicator(
                            color = MaterialTheme.colors.onPrimary,
                            modifier = Modifier.size(20.dp)
                        )
                    } else {
                        Text("Blend")
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                if (error != null) {
                    Text(error!!, color = MaterialTheme.colors.error)
                }

                if (recommendations.isNotEmpty()) {
                    Divider()
                    Spacer(modifier = Modifier.height(8.dp))
                    Text("Recommended for the group", style = MaterialTheme.typography.h6)
                    LazyColumn(modifier = Modifier.weight(1f)) {
                        items(recommendations) { restaurant ->
                            RecommendationItem(restaurant = restaurant)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun RecommendationItem(restaurant: RestaurantRecommendation) {
    ListItem(
        text = { Text(restaurant.name) },
        secondaryText = {
            Column {
                restaurant.cuisine?.let { Text(it) }
                Text("Score: ${restaurant.score}")
            }
        }
    )
    Divider()
}
