package com.bigback.ui.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.bigback.data.Repository
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

data class AuthUiState(
    val isLoading: Boolean = false,
    val error: String? = null,
    val isLoggedIn: Boolean = false
)

class AuthViewModel(
    private val repository: Repository
) : ViewModel() {

    private val _state = MutableStateFlow(AuthUiState())
    val state: StateFlow<AuthUiState> = _state.asStateFlow()

    fun login(phoneOrEmail: String, password: String) = viewModelScope.launch {
        _state.value = _state.value.copy(isLoading = true, error = null)
        try {
            repository.login(phoneOrEmail, password)
            _state.value = _state.value.copy(isLoading = false, isLoggedIn = true)
        } catch (e: Exception) {
            _state.value = _state.value.copy(isLoading = false, error = e.message ?: "Login failed")
        }
    }

    fun signup(username: String, phoneOrEmail: String, password: String) = viewModelScope.launch {
        _state.value = _state.value.copy(isLoading = true, error = null)
        try {
            repository.signup(username, phoneOrEmail, password)
            _state.value = _state.value.copy(isLoading = false, isLoggedIn = true)
        } catch (e: Exception) {
            _state.value = _state.value.copy(isLoading = false, error = e.message ?: "Signup failed")
        }
    }
}
