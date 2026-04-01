package com.bigback.viewmodel

import android.content.Context
import androidx.lifecycle.ViewModel
import kotlinx.coroutines.flow.*
import com.bigback.data.Repository
import com.bigback.data.SessionManager
import com.bigback.data.RetrofitClient
import com.bigback.data.BigBackApi
import okhttp3.OkHttpClient

sealed class NavRoute {
    object Splash : NavRoute()
    object Auth : NavRoute()
    object Feed : NavRoute()
    data class UserProfile(val userId: String) : NavRoute()
    object Friends : NavRoute()
    object CreatePost : NavRoute()
    object SavedPlaces : NavRoute()
    object MapView : NavRoute()
    object Blend : NavRoute()
    object RestaurantSearch : NavRoute()
}

class RootViewModel(context: Context) : ViewModel() {

    private val baseUrl = "http://10.0.2.2:3000/"
    val sessionManager = SessionManager(context)
    private val okHttp: OkHttpClient = RetrofitClient.okHttpClient(sessionManager)
    private val api: BigBackApi = RetrofitClient.create(okHttp, baseUrl)
    val repository = Repository(api, sessionManager)

    private val _navState = MutableStateFlow<NavRoute>(NavRoute.Splash)
    val navState: StateFlow<NavRoute> = _navState.asStateFlow()

    init {
        determineStartDestination()
    }

    private fun determineStartDestination() {
        if (sessionManager.isLoggedIn()) {
            _navState.value = NavRoute.Feed
        } else {
            _navState.value = NavRoute.Auth
        }
    }

    fun navigate(route: NavRoute) {
        _navState.value = route
    }

    fun logout() {
        repository.logout()
        _navState.value = NavRoute.Auth
    }

    fun onAuthSuccess() {
        _navState.value = NavRoute.Feed
    }

    fun goBack() {
        _navState.value = NavRoute.Feed
    }
}
