package com.maillardmap.ui.friends

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
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.unit.dp
import com.maillardmap.common.PreviewTheme
import com.maillardmap.data.Repository
import com.maillardmap.domain.Friendship
import com.maillardmap.domain.User
import com.maillardmap.ui.restaurant.RestaurantSearchDialog
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@Composable
fun FriendsScreen(
    repository: Repository,
    currentUserId: String,
    onOpenBlend: () -> Unit,
    onNavigateBack: () -> Unit = {}
) {
    var friends by remember { mutableStateOf<List<Friendship>>(emptyList()) }
    var pendingRequests by remember { mutableStateOf<List<Friendship>>(emptyList()) }
    var sentRequests by remember { mutableStateOf<List<Friendship>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }
    var showAddFriend by remember { mutableStateOf(false) }
    var showRestaurantSearch by remember { mutableStateOf(false) }
    var findFriendsQuery by remember { mutableStateOf("") }
    var findFriendsRaw by remember { mutableStateOf<List<User>>(emptyList()) }
    var findFriendsSearching by remember { mutableStateOf(false) }
    var findFriendsSearchError by remember { mutableStateOf<String?>(null) }

    val excludedFromFindFriends = remember(friends, pendingRequests, sentRequests, currentUserId) {
        buildSet {
            if (currentUserId.isNotBlank()) add(currentUserId)
            friends.forEach { add(it.friendId) }
            pendingRequests.forEach { add(it.friendId) }
            sentRequests.forEach { add(it.friendId) }
        }
    }

    val findFriendsResults = remember(findFriendsRaw, excludedFromFindFriends) {
        findFriendsRaw.filter { it.id !in excludedFromFindFriends }
    }

    LaunchedEffect(findFriendsQuery) {
        delay(400)
        val q = normalizedFindFriendsQuery(findFriendsQuery)
        if (q.isEmpty()) {
            findFriendsRaw = emptyList()
            findFriendsSearchError = null
            findFriendsSearching = false
            return@LaunchedEffect
        }
        findFriendsSearching = true
        findFriendsSearchError = null
        try {
            val users = repository.searchUsers(q)
            if (normalizedFindFriendsQuery(findFriendsQuery) != q) return@LaunchedEffect
            findFriendsRaw = users
        } catch (e: Exception) {
            if (normalizedFindFriendsQuery(findFriendsQuery) == q) {
                findFriendsSearchError = e.message ?: "Search failed"
                findFriendsRaw = emptyList()
            }
        } finally {
            findFriendsSearching = false
        }
    }

    suspend fun loadFriends() {
        try {
            val allFriends = repository.getFriends()
            friends = allFriends.filter { it.status == "accepted" }
            pendingRequests = allFriends.filter { it.status == "pending" && it.incomingPending != false }
            sentRequests = allFriends.filter { it.status == "pending" && it.incomingPending == false }
            error = null
        } catch (e: Exception) {
            error = "Failed to load friends"
        } finally {
            isLoading = false
        }
    }

    LaunchedEffect(Unit) { loadFriends() }

    val scope = rememberCoroutineScope()

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
                        item {
                            Text(
                                text = "Find friends",
                                style = MaterialTheme.typography.h6,
                                modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 8.dp)
                            )
                            OutlinedTextField(
                                value = findFriendsQuery,
                                onValueChange = { findFriendsQuery = it },
                                label = { Text("Search by username") },
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 16.dp, vertical = 8.dp),
                                singleLine = true,
                                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search)
                            )
                            val trimmed = normalizedFindFriendsQuery(findFriendsQuery)
                            when {
                                trimmed.isEmpty() -> Text(
                                    "Type a username to search",
                                    style = MaterialTheme.typography.body2,
                                    color = MaterialTheme.colors.onSurface.copy(alpha = 0.6f),
                                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)
                                )
                                findFriendsSearchError != null -> Text(
                                    findFriendsSearchError!!,
                                    color = MaterialTheme.colors.error,
                                    style = MaterialTheme.typography.body2,
                                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)
                                )
                                findFriendsSearching -> {
                                    Box(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .padding(16.dp),
                                        contentAlignment = Alignment.Center
                                    ) {
                                        CircularProgressIndicator()
                                    }
                                }
                                findFriendsRaw.isNotEmpty() && findFriendsResults.isEmpty() -> Text(
                                    "Everyone matching is already a friend or has a pending request",
                                    style = MaterialTheme.typography.body2,
                                    color = MaterialTheme.colors.onSurface.copy(alpha = 0.6f),
                                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)
                                )
                                findFriendsResults.isEmpty() -> Text(
                                    "No users match",
                                    style = MaterialTheme.typography.body2,
                                    color = MaterialTheme.colors.onSurface.copy(alpha = 0.6f),
                                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)
                                )
                            }
                        }
                        items(findFriendsResults, key = { it.id }) { user ->
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 16.dp, vertical = 8.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(user.username, style = MaterialTheme.typography.body1)
                                }
                                OutlinedButton(
                                    onClick = {
                                        scope.launch {
                                            try {
                                                repository.sendFriendRequest(user.id)
                                                loadFriends()
                                            } catch (e: Exception) {
                                                error = e.message ?: "Failed to send request"
                                            }
                                        }
                                    },
                                    contentPadding = PaddingValues(horizontal = 12.dp)
                                ) {
                                    Text("Add")
                                }
                            }
                        }
                        item { Divider(modifier = Modifier.padding(top = 8.dp)) }

                        if (friends.isEmpty() && pendingRequests.isEmpty() && sentRequests.isEmpty()) {
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
                                    onDecline = {
                                        scope.launch {
                                            try {
                                                repository.removeFriend(friendship.friendId)
                                                loadFriends()
                                            } catch (e: Exception) {
                                                error = e.message ?: "Failed to decline"
                                            }
                                        }
                                    },
                                    onAccept = {
                                        scope.launch {
                                            try {
                                                repository.acceptFriendRequest(friendship.friendId)
                                                loadFriends()
                                            } catch (e: Exception) {
                                                error = e.message ?: "Failed to accept"
                                            }
                                        }
                                    }
                                )
                            }
                        }

                        if (sentRequests.isNotEmpty()) {
                            item {
                                Text(
                                    text = "Request sent",
                                    style = MaterialTheme.typography.h6,
                                    modifier = Modifier.padding(16.dp)
                                )
                                Divider()
                            }
                            items(sentRequests, key = { it.id }) { friendship ->
                                SentRequestItem(
                                    username = friendship.friendUsername ?: friendship.friendId,
                                    onRevoke = {
                                        scope.launch {
                                            try {
                                                repository.removeFriend(friendship.friendId)
                                                loadFriends()
                                            } catch (e: Exception) {
                                                error = e.message ?: "Failed to revoke"
                                            }
                                        }
                                    }
                                )
                            }
                        }

                        if (friends.isNotEmpty()) {
                            item { Divider() }
                            items(friends, key = { it.id }) { friendship ->
                                FriendItem(
                                    username = friendship.friendUsername ?: friendship.friendId,
                                    onRemove = {
                                        scope.launch {
                                            try {
                                                repository.removeFriend(friendship.friendId)
                                                loadFriends()
                                            } catch (e: Exception) {
                                                error = e.message ?: "Failed to remove friend"
                                            }
                                        }
                                    }
                                )
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
                    scope.launch { loadFriends() }
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

private fun normalizedFindFriendsQuery(raw: String): String {
    var t = raw.trim()
    if (t.startsWith("@")) {
        t = t.drop(1).trim()
    }
    return t
}

@Composable
private fun PendingFriendItem(username: String, onDecline: () -> Unit, onAccept: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            username,
            style = MaterialTheme.typography.body1,
            modifier = Modifier.weight(1f, fill = false)
        )
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            TextButton(onClick = onDecline) { Text("Decline") }
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
private fun SentRequestItem(username: String, onRevoke: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(username, style = MaterialTheme.typography.body1)
            Text(
                "Waiting for response",
                style = MaterialTheme.typography.caption,
                color = MaterialTheme.colors.onSurface.copy(alpha = 0.6f)
            )
        }
        OutlinedButton(onClick = onRevoke, contentPadding = PaddingValues(horizontal = 12.dp)) {
            Text("Revoke")
        }
    }
}

@Composable
private fun FriendItem(username: String, subtitle: String? = null, onRemove: (() -> Unit)? = null) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Row(
            modifier = Modifier.weight(1f),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Default.Person,
                contentDescription = null,
                tint = MaterialTheme.colors.primary,
                modifier = Modifier.padding(end = 16.dp)
            )
            Column {
                Text(username, style = MaterialTheme.typography.body1)
                if (subtitle != null) {
                    Text(subtitle, style = MaterialTheme.typography.caption, color = MaterialTheme.colors.onSurface.copy(alpha = 0.6f))
                }
            }
        }
        if (onRemove != null) {
            TextButton(onClick = onRemove) { Text("Remove", color = MaterialTheme.colors.error) }
        }
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
    val dialogScope = rememberCoroutineScope()

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
                    dialogScope.launch {
                        try {
                            val users = repository.searchUsers(query.trim())
                            val match = users.firstOrNull { it.username.equals(query.trim(), ignoreCase = true) }
                                ?: throw Exception("User not found")
                            repository.sendFriendRequest(match.id)
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
