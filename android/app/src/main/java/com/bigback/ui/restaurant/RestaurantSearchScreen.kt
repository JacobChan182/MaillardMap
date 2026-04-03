package com.maillardmap.ui.restaurant

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.ui.unit.dp
import androidx.compose.ui.Alignment
import com.maillardmap.common.PreviewTheme
import com.maillardmap.data.Repository
import com.maillardmap.domain.Restaurant

@Composable
fun RestaurantSearchScreen(
    repository: Repository,
    onRestaurantSelected: ((Restaurant) -> Unit)? = null,
    onNavigateBack: () -> Unit
) {
    var query by remember { mutableStateOf("") }
    var results by remember { mutableStateOf<List<Restaurant>>(emptyList()) }
    var isSearching by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    val scope = rememberCoroutineScope()

    val doSearch = {
        if (query.isBlank()) return@doSearch
        isSearching = true
        error = null
        scope.launch {
            try {
                results = repository.searchRestaurants(query)
            } catch (e: Exception) {
                error = e.message ?: "Search failed"
            } finally {
                isSearching = false
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Search Restaurants") },
                navigationIcon = {
                    if (onNavigateBack != null) {
                        IconButton(onClick = onNavigateBack) {
                            Icon(Icons.Default.ArrowBack, "Back")
                        }
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier.padding(padding).padding(16.dp)
        ) {
            TextField(
                value = query,
                onValueChange = {
                    query = it
                    if (it.isEmpty()) {
                        results = emptyList()
                    }
                },
                placeholder = { Text("Restaurant or cuisine...") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                leadingIcon = { Icon(Icons.Default.Search, null) },
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                keyboardActions = KeyboardActions(
                    onSearch = { doSearch() }
                )
            )

            Spacer(modifier = Modifier.height(8.dp))

            Button(
                onClick = { doSearch() },
                modifier = Modifier.fillMaxWidth(),
                enabled = !isSearching
            ) {
                Text("Search")
            }

            Spacer(modifier = Modifier.height(16.dp))

            when {
                isSearching -> {
                    Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                }
                error != null -> {
                    Text(error!!, color = MaterialTheme.colors.error)
                }
                results.isEmpty() -> {
                    Text("Type to search for restaurants...")
                }
                else -> {
                    LazyColumn(modifier = Modifier.fillMaxWidth()) {
                        items(results) { restaurant ->
                            ListItem(
                                text = { Text(restaurant.name) },
                                secondaryText = { Text(restaurant.cuisine ?: "") },
                                onClick = { onRestaurantSelected?.invoke(restaurant) }
                            )
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun RestaurantSearchDialog(
    onDismiss: () -> Unit,
    onRestaurantSelected: (Restaurant) -> Unit,
    repository: Repository
) {
    var query by remember { mutableStateOf("") }
    var results by remember { mutableStateOf<List<Restaurant>>(emptyList()) }
    var isSearching by remember { mutableStateOf(false) }

    val scope = rememberCoroutineScope()

    val doSearch = {
        if (query.isBlank()) return@doSearch
        isSearching = true
        scope.launch {
            try {
                results = repository.searchRestaurants(query)
            } catch (e: Exception) {
            } finally {
                isSearching = false
            }
        }
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Search Restaurant") },
        text = {
            Column {
                TextField(
                    value = query,
                    onValueChange = { query = it },
                    label = { Text("Search...") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                    keyboardActions = KeyboardActions(onSearch = { doSearch() })
                )
                Spacer(modifier = Modifier.height(12.dp))
                when {
                    isSearching -> {
                        CircularProgressIndicator(
                            modifier = Modifier.align(Alignment.CenterHorizontally)
                        )
                    }
                    query.isEmpty() -> Text("Type to search...")
                    results.isEmpty() -> Text("No results found")
                    else -> {
                        LazyColumn(modifier = Modifier.heightIn(max = 300.dp)) {
                            items(results) { restaurant ->
                                ListItem(
                                    text = { Text(restaurant.name) },
                                    secondaryText = { Text(restaurant.cuisine ?: "") },
                                    onClick = { onRestaurantSelected(restaurant) }
                                )
                            }
                        }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) { Text("Close") }
        }
    )
}
