package com.bigback.ui.friends

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
import com.bigback.ui.restaurant.RestaurantSearchDialog

@Composable
fun FriendsScreen(
    repository: Repository,
    currentUserId: String,
    onOpenBlend: () -> Unit,
    onNavigateBack: () -> Unit = {}
) {
    var friends by remember { mutableStateOf<List<Friendship>>(emptyList()) }
    var pendingRequests by remember { mutableStateOf<List<Friendship>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }
    var showAddFriend by remember { mutableStateOf(false) }
    var showRestaurantSearch by remember { mutableStateOf(false) }

    suspend fun loadFriends() {
        try {
            val allFriends = repository.getFriends()
            friends = allFriends.filter { it.status == "accepted" }
            pendingRequests = allFriends.filter { it.status == "pending" }
            error = null
        } catch (e: Exception) {
            error = "Failed to load friends"
        } finally {
            isLoading = false
        }
    }

    LaunchedEffect(Unit) { loadFriends() }

    PreviewTheme {
        Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text("Friends") },
                    navigationIcon = {
                        IconButton(onClick = onNavigateBack) {
                            Icon(Icons.Default.ArrowBack, "Back")
                        }
                    },
                    actions = {
                        IconButton(onClick = onOpenBlend) {
                            Icon(Icons.Default.Star, "Blend")
                        }
                        IconButton(onClick = { showRestaurantSearch = true }) {
                            Icon(Icons.Default.Search, "Search restaurants")
                        }
                        IconButton(onClick = { showAddFriend = true }) {
                            Icon(Icons.Default.PersonAdd, "Add friend")
                        }
                    }
                )
            }
        ) { padding ->
            Column(
                modifier = Modifier.padding(padding).fillMaxSize()
            ) {
                if (isLoading) {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                } else {
                    LazyColumn(modifier = Modifier.fillMaxWidth()) {
                        if (friends.isEmpty() && pendingRequests.isEmpty()) {
                            item {
                                Box(
                                    modifier = Modifier.fillMaxWidth().padding(top = 48.dp),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text("No friends yet. Add friends to see their activity!")
                                }
                            }
                        }

                        if (pendingRequests.isNotEmpty()) {
                            item {
                                Text(
                                    text = "Pending Requests",
                                    style = MaterialTheme.typography.h6,
                                    modifier = Modifier.padding(16.dp)
                                )
                                Divider()
                            }
                            items(pendingRequests, key = { it.id }) { friendship ->
                                PendingFriendItem(
                                    username = friendship.friendUsername ?: "?",
                                    onAccept = {
                                        val scope = rememberCoroutineScope()
                                        scope.launch {
                                            try {
                                                repository.acceptFriend(friendship.id)
                                                loadFriends()
                                            } catch (e: Exception) {
                                                error = e.message ?: "Failed to accept"
                                            }
                                        }
                                    }
                                )
                            }
                        }

                        if (friends.isNotEmpty()) {
                            item { Divider() }
                            items(friends, key = { it.id }) { friendship ->
                                FriendItem(username = friendship.friendUsername ?: friendship.friendId)
                            }
                        }
                    }
                }

                error?.let {
                    Text(
                        text = it,
                        color = MaterialTheme.colors.error,
                        modifier = Modifier.padding(16.dp)
                    )
                }
            }
        }

        if (showAddFriend) {
            AddFriendDialog(
                repository = repository,
                onDismiss = { showAddFriend = false },
                onSent = {
                    showAddFriend = false
                    loadFriends()
                },
                onError = { msg -> error = msg }
            )
        }

        if (showRestaurantSearch) {
            RestaurantSearchDialog(
                repository = repository,
                onDismiss = { showRestaurantSearch = false },
                onRestaurantSelected = { _ -> showRestaurantSearch = false }
            )
        }
    }
}

@Composable
private fun PendingFriendItem(username: String, onAccept: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
            .height(56.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(username, style = MaterialTheme.typography.body1)
        Row {
            OutlinedButton(
                onClick = onAccept,
                contentPadding = PaddingValues(horizontal = 8.dp)
            ) {
                Icon(Icons.Default.Check, contentDescription = "Accept", modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(4.dp))
                Text("Accept")
            }
        }
    }
}

@Composable
private fun FriendItem(username: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp)
            .height(48.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = Icons.Default.Person,
            contentDescription = null,
            tint = MaterialTheme.colors.primary,
            modifier = Modifier.padding(end = 16.dp)
        )
        Text(username, style = MaterialTheme.typography.body1)
    }
}

@Composable
private fun AddFriendDialog(
    repository: Repository,
    onDismiss: () -> Unit,
    onSent: () -> Unit,
    onError: (String) -> Unit
) {
    var query by remember { mutableStateOf("") }
    var isSending by remember { mutableStateOf(false) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Add Friend") },
        text = {
            TextField(
                value = query,
                onValueChange = { query = it },
                label = { Text("Username") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true
            )
        },
        confirmButton = {
            Button(
                onClick = {
                    isSending = true
                    val scope = rememberCoroutineScope()
                    scope.launch {
                        try {
                            repository.requestFriend(query)
                            onSent()
                        } catch (e: Exception) {
                            onError(e.message ?: "Failed to send request")
                        } finally {
                            isSending = false
                        }
                    }
                },
                enabled = !isSending && query.isNotBlank()
            ) {
                if (isSending) CircularProgressIndicator(
                    color = MaterialTheme.colors.onPrimary, modifier = Modifier.size(20.dp)
                ) else Text("Send")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        }
    )
}
