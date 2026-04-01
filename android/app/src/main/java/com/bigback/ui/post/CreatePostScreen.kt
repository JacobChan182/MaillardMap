package com.bigback.ui.post

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import coil.compose.rememberAsyncImagePainter
import com.bigback.common.PreviewTheme
import com.bigback.data.Repository
import com.bigback.domain.Restaurant
import com.bigback.ui.restaurant.RestaurantSearchDialog

@Composable
fun CreatePostScreen(
    repository: Repository,
    onPostCreated: () -> Unit,
    onNavigateBack: () -> Unit
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("New Post") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.Default.ArrowBack, "Back")
                    }
                }
            )
        }
    ) { padding ->
        CreatePostContent(
            repository = repository,
            modifier = Modifier.padding(padding),
            onPostCreated = onPostCreated
        )
    }
}

@Composable
private fun CreatePostContent(
    repository: Repository,
    modifier: Modifier,
    onPostCreated: () -> Unit
) {
    var comment by remember { mutableStateOf("") }
    var selectedRestaurant by remember { mutableStateOf<Restaurant?>(null) }
    var showRestaurantPicker by remember { mutableStateOf(false) }
    var photoUris by remember { mutableStateOf<List<Uri>>(emptyList()) }
    var isLoading by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    val pickMedia = rememberLauncherForActivityResult(
        ActivityResultContracts.PickMultipleVisualMedia(3)
    ) { uris ->
        photoUris = uris.take(3)
    }

    PreviewTheme {
        Column(
            modifier = modifier
                .padding(16.dp)
                .verticalScroll(rememberScrollState())
                .fillMaxSize()
        ) {
            // Restaurant selector
            Text("Restaurant", style = MaterialTheme.typography.subtitle1)
            Spacer(modifier = Modifier.height(8.dp))

            if (selectedRestaurant != null) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(
                        text = selectedRestaurant!!.name,
                        color = MaterialTheme.colors.primary,
                        modifier = Modifier.weight(1f)
                    )
                    TextButton(onClick = { selectedRestaurant = null }) {
                        Text("Change")
                    }
                }
            } else {
                OutlinedButton(onClick = { showRestaurantPicker = true }) {
                    Icon(Icons.Default.Search, null)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Search for a restaurant")
                }
            }

            Spacer(modifier = Modifier.height(16.dp))
            Divider()

            // Photos (up to 3)
            Spacer(modifier = Modifier.height(16.dp))
            Text("Photos (up to 3)", style = MaterialTheme.typography.subtitle1)
            Spacer(modifier = Modifier.height(8.dp))

            Row {
                photoUris.forEach { uri ->
                    Image(
                        painter = rememberAsyncImagePainter(uri),
                        contentDescription = null,
                        modifier = Modifier
                            .size(80.dp)
                            .padding(4.dp)
                    )
                }
                if (photoUris.size < 3) {
                    IconButton(onClick = {
                        pickMedia.launch(
                            PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
                        )
                    }) {
                        Icon(Icons.Default.AddAPhoto, "Add photo")
                    }
                }
            }

            Spacer(modifier = Modifier.height(16.dp))
            Divider()

            // Comment
            Spacer(modifier = Modifier.height(16.dp))
            Text("Comment (max 200 chars)", style = MaterialTheme.typography.subtitle1)
            Spacer(modifier = Modifier.height(4.dp))

            OutlinedTextField(
                value = comment,
                onValueChange = { if (it.length <= 200) comment = it },
                placeholder = { Text("What did you think?") },
                maxLines = 3,
                modifier = Modifier.fillMaxWidth(),
                trailingIcon = {
                    Text(
                        text = "${comment.length}/200",
                        style = MaterialTheme.typography.caption,
                        color = MaterialTheme.colors.onSurface.copy(alpha = 0.5f)
                    )
                }
            )

            Spacer(modifier = Modifier.height(24.dp))

            if (error != null) {
                Text(error!!, color = MaterialTheme.colors.error)
                Spacer(modifier = Modifier.height(8.dp))
            }

            Button(
                onClick = {
                    error = null
                    val restaurant = selectedRestaurant
                    if (restaurant == null) {
                        error = "Select a restaurant first"
                        return@Button
                    }
                    isLoading = true
                    val scope = rememberCoroutineScope()
                    scope.launch {
                        try {
                            // Note: in production, upload photo URLs to S3 first
                            repository.createPost(
                                foursquareId = restaurant.foursquareId,
                                comment = comment,
                                photoUrls = emptyList()
                            )
                            onPostCreated()
                        } catch (e: Exception) {
                            error = e.message ?: "Failed to create post"
                            isLoading = false
                        }
                    }
                },
                modifier = Modifier.fillMaxWidth()
            ) {
                if (isLoading) {
                    CircularProgressIndicator(color = MaterialTheme.colors.onPrimary)
                } else {
                    Text("Post")
                }
            }
        }

        // Restaurant picker
        if (showRestaurantPicker) {
            RestaurantSearchDialog(
                repository = repository,
                onDismiss = { showRestaurantPicker = false },
                onRestaurantSelected = { restaurant ->
                    selectedRestaurant = restaurant
                    showRestaurantPicker = false
                }
            )
        }
    }
}
