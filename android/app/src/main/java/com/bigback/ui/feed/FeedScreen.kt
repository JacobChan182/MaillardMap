package com.maillardmap.ui.feed

import android.content.Context
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material.ExperimentalMaterialApi
import androidx.compose.material.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.material.pullrefresh.PullRefreshIndicator
import androidx.compose.material.pullrefresh.pullRefresh
import androidx.compose.material.pullrefresh.rememberPullRefreshState
import coil.compose.AsyncImage
import kotlinx.coroutines.launch
import coil.request.ImageRequest
import com.maillardmap.domain.Post
import com.maillardmap.data.Repository
import com.maillardmap.common.PreviewTheme

@OptIn(ExperimentalMaterialApi::class)
@Composable
fun FeedScreen(
    repository: Repository,
    onNavigateToUser: (String) -> Unit
) {
    var posts by remember { mutableStateOf<List<Post>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    var isError by remember { mutableStateOf(false) }

    suspend fun loadFeed() {
        try {
            posts = repository.getFeed()
            isError = false
        } catch (_: Exception) {
            isError = true
        } finally {
            isLoading = false
        }
    }

    LaunchedEffect(Unit) { loadFeed() }

    val scope = rememberCoroutineScope()
    var refreshing by remember { mutableStateOf(false) }
    val pullRefreshState = rememberPullRefreshState(
        refreshing,
        onRefresh = {
            scope.launch {
                refreshing = true
                loadFeed()
                refreshing = false
            }
        },
    )

    PreviewTheme {
        if (isLoading) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
        } else if (isError) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("Failed to load feed")
                    Spacer(modifier = Modifier.height(8.dp))
                    Button(onClick = {
                        scope.launch {
                            isLoading = true
                            loadFeed()
                        }
                    }) { Text("Retry") }
                }
            }
        } else {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .pullRefresh(pullRefreshState),
            ) {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(bottom = 16.dp)
                ) {
                    items(posts) { post ->
                        PostCard(
                            post = post,
                            onLike = { /* TODO: toggle like */ },
                            onViewUser = onNavigateToUser
                        )
                    }
                    if (posts.isEmpty()) {
                        item {
                            Box(
                                modifier = Modifier.fillMaxWidth().padding(vertical = 48.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Text("No posts yet. Add some friends!")
                            }
                        }
                    }
                }
                PullRefreshIndicator(refreshing, pullRefreshState, Modifier.align(Alignment.TopCenter))
            }
        }
    }
}

@Composable
private fun PostCard(
    post: Post,
    onLike: () -> Unit,
    onViewUser: (String) -> Unit
) {
    var localLiked by remember { mutableStateOf(post.liked) }
    var localLikeCount by remember { mutableStateOf(post.likeCount) }

    Card(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 6.dp),
        elevation = 4.dp
    ) {
        Column(modifier = Modifier.padding(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = post.username ?: "?",
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.clickable { onViewUser(post.userId) }
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = formatTimestamp(post.createdAt),
                    color = MaterialTheme.colors.onSurface.copy(alpha = 0.5f)
                )
            }

            post.restaurantName?.let { name ->
                Text(
                    text = name,
                    color = MaterialTheme.colors.primary,
                    fontWeight = FontWeight.SemiBold
                )
            }

            post.comment?.let { comment ->
                Text(
                    text = comment,
                    modifier = Modifier.padding(vertical = 4.dp)
                )
            }

            if (post.photos.isNotEmpty()) {
                LazyRow(
                    modifier = Modifier.fillMaxWidth(),
                    contentPadding = PaddingValues(vertical = 4.dp)
                ) {
                    items(post.photos) { photo ->
                        AsyncImage(
                            model = ImageRequest.Builder(androidx.compose.ui.platform.LocalContext.current)
                                .data(photo.url)
                                .crossfade(true)
                                .build(),
                            contentDescription = null,
                            modifier = Modifier
                                .width(200.dp)
                                .aspectRatio(1f),
                            contentScale = ContentScale.Crop
                        )
                    }
                }
            }

            Row(
                modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    IconButton(onClick = {
                        localLiked = !localLiked
                        localLikeCount += if (localLiked) 1 else -1
                        // TODO: call API
                    }) {
                        Icon(
                            imageVector = if (localLiked) Icons.Default.Favorite else Icons.Default.FavoriteBorder,
                            contentDescription = "like",
                            tint = MaterialTheme.colors.primary
                        )
                    }
                    Text("$localLikeCount")
                }
                IconButton(onClick = { /* saved bookmark */ }) {
                    Icon(Icons.Default.BookmarkBorder, "save", tint = MaterialTheme.colors.onSurface.copy(alpha = 0.5f))
                }
            }
        }
    }
}

private fun formatTimestamp(ts: String): String {
    return try {
        val instant = java.time.Instant.parse(ts)
        val now = java.time.Instant.now()
        val minutes = java.time.temporal.ChronoUnit.MINUTES.between(instant, now)
        when {
            minutes < 1 -> "just now"
            minutes < 60 -> "${minutes}m ago"
            minutes < 1440 -> "${minutes / 60}h ago"
            else -> "${minutes / 1440}d ago"
        }
    } catch (_: Exception) {
        ts
    }
}
