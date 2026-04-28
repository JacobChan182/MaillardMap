package com.maillardmap.ui

import android.content.Context
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.material.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalFocusManager
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import androidx.navigation.compose.*
import com.maillardmap.viewmodel.RootViewModel
import com.maillardmap.viewmodel.NavRoute
import com.maillardmap.ui.auth.AuthScreen
import com.maillardmap.ui.feed.FeedScreen
import com.maillardmap.ui.post.CreatePostScreen
import com.maillardmap.ui.friends.FriendsScreen
import com.maillardmap.ui.saved.SavedPlacesScreen
import com.maillardmap.ui.map.MapScreen
import com.maillardmap.ui.restaurant.RestaurantSearchDialog
import com.maillardmap.common.BigBackTheme
import com.maillardmap.common.BigBackBottomNav
import com.maillardmap.common.PreviewTheme

@Composable
fun BigBackApp(context: Context) {
    val focusManager = LocalFocusManager.current
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

        Box(
            modifier = Modifier
                .fillMaxSize()
                .pointerInput(Unit) {
                    detectTapGestures(onTap = { focusManager.clearFocus() })
                }
        ) {
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
                MainShell(navController = navController, vm = vm, defaultTab = "feed")
            }

            composable("friends") {
                MainShell(navController = navController, vm = vm, defaultTab = "friends")
            }

            composable("create_post") {
                CreatePostScreen(
                    repository = vm.repository,
                    onPostCreated = { navController.popBackStack() },
                    onNavigateBack = { navController.popBackStack() }
                )
            }

            composable("saved") {
                MainShell(navController = navController, vm = vm, defaultTab = "saved")
            }

            composable("map") {
                MainShell(navController = navController, vm = vm, defaultTab = "map")
            }
            }
        }
    }
}

@OptIn(ExperimentalMaterialApi::class)
@Composable
fun MainShell(
    navController: NavHostController,
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
                        Icon(Icons.Default.AutoAwesome, "Blend tastes")
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
                onRouteClicked = { route -> navController.navigate(route) { launchSingleTop = true } }
            )
        },
        floatingActionButton = {
            FloatingActionButton(
                onClick = { navController.navigate("create_post") },
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
                    currentUserId = vm.currentUserId().orEmpty(),
                    onOpenBlend = { showBlend = true }
                )
                "saved" -> SavedPlacesScreen(repository = vm.repository)
                "map" -> MapScreen(repository = vm.repository)
            }
        }
    }

    if (showBlend) {
        com.maillardmap.ui.blend.BlendScreen(
            repository = vm.repository,
            currentUserId = vm.currentUserId().orEmpty(),
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
