package com.bigback.ui

import android.content.Context
import androidx.compose.foundation.layout.*
import androidx.compose.material.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.compose.*
import com.bigback.viewmodel.RootViewModel
import com.bigback.viewmodel.NavRoute
import com.bigback.ui.auth.AuthScreen
import com.bigback.ui.feed.FeedScreen
import com.bigback.ui.post.CreatePostScreen
import com.bigback.ui.friends.FriendsScreen
import com.bigback.ui.saved.SavedPlacesScreen
import com.bigback.ui.map.MapScreen
import com.bigback.ui.restaurant.RestaurantSearchDialog
import com.bigback.common.BigBackTheme
import com.bigback.common.BigBackBottomNav
import com.bigback.common.PreviewTheme

@Composable
fun BigBackApp(context: Context) {
    BigBackTheme {
        val vm: RootViewModel = viewModel(
            factory = object : androidx.lifecycle.ViewModelProvider.Factory {
                @Suppress("UNCHECKED_CAST")
                override fun <T : androidx.lifecycle.ViewModel> create(modelClass: Class<T>): T =
                    RootViewModel(context) as T
            }
        )

        val navController = rememberNavController()
        val navState by vm.navState.collectAsState()

        NavHost(
            navController = navController,
            startDestination = "splash"
        ) {
            composable("splash") {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    LaunchedEffect(navState) {
                        when (navState) {
                            is NavRoute.Auth -> {
                                navController.navigate("auth") {
                                    popUpTo("splash") { inclusive = true }
                                }
                            }
                            is NavRoute.Feed -> {
                                navController.navigate("feed") {
                                    popUpTo("splash") { inclusive = true }
                                }
                            }
                            else -> {}
                        }
                    }
                    CircularProgressIndicator()
                }
            }

            composable("auth") {
                AuthScreen(
                    onAuthSuccess = {
                        navController.navigate("feed") {
                            popUpTo("auth") { inclusive = true }
                        }
                    }
                )
            }

            composable("feed") {
                MainShell(vm = vm, defaultTab = "feed")
            }

            composable("friends") {
                MainShell(vm = vm, defaultTab = "friends")
            }

            composable("create_post") {
                CreatePostScreen(
                    repository = vm.repository,
                    onPostCreated = { navController.popBackStack() },
                    onNavigateBack = { navController.popBackStack() }
                )
            }

            composable("saved") {
                MainShell(vm = vm, defaultTab = "saved")
            }

            composable("map") {
                MainShell(vm = vm, defaultTab = "map")
            }
        }
    }
}

@OptIn(ExperimentalMaterialApi::class)
@Composable
fun MainShell(
    vm: RootViewModel,
    defaultTab: String
) {
    val scaffoldState = rememberScaffoldState()
    var showRestaurantSearch by remember { mutableStateOf(false) }
    var showBlend by remember { mutableStateOf(false) }

    Scaffold(
        scaffoldState = scaffoldState,
        topBar = {
            TopAppBar(
                title = { Text("BigBack") },
                actions = {
                    IconButton(onClick = { showBlend = true }) {
                        Icon(Icons.Default.Blend, "Blend tastes")
                    }
                    IconButton(onClick = { showRestaurantSearch = true }) {
                        Icon(Icons.Default.Search, "Search restaurants")
                    }
                    IconButton(onClick = { vm.logout() }) {
                        Icon(Icons.Default.ExitToApp, "Logout")
                    }
                }
            )
        },
        bottomBar = {
            BigBackBottomNav(
                currentRoute = defaultTab,
                onRouteClicked = { route -> vm.navigate(route) }
            )
        },
        floatingActionButton = {
            FloatingActionButton(
                onClick = { vm.navigate(NavRoute.CreatePost) },
                backgroundColor = MaterialTheme.colors.primary
            ) {
                Icon(Icons.Default.Add, "Create Post", tint = MaterialTheme.colors.onPrimary)
            }
        }
    ) { padding ->
        Column(modifier = Modifier.padding(padding).fillMaxSize()) {
            when (defaultTab) {
                "feed" -> FeedScreen(
                    repository = vm.repository,
                    onNavigateToUser = { userId ->
                        // User profile navigation
                    }
                )
                "friends" -> FriendsScreen(
                    repository = vm.repository,
                    currentUserId = vm.currentUserId() ?: "",
                    onOpenBlend = { showBlend = true }
                )
                "saved" -> SavedPlacesScreen(repository = vm.repository)
                "map" -> MapScreen(repository = vm.repository)
            }
        }
    }

    if (showBlend) {
        com.bigback.ui.blend.BlendScreen(
            repository = vm.repository,
            currentUserId = vm.currentUserId() ?: "",
            onNavigateBack = { showBlend = false }
        )
    }

    if (showRestaurantSearch) {
        RestaurantSearchDialog(
            onDismiss = { showRestaurantSearch = false },
            onRestaurantSelected = { restaurant ->
                showRestaurantSearch = false
            },
            repository = vm.repository
        )
    }
}
