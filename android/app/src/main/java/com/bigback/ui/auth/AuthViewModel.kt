package com.maillardmap.ui.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.maillardmap.data.Repository
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import retrofit2.HttpException

data class AuthUiState(
    val isLoading: Boolean = false,
    val error: String? = null,
    val isLoggedIn: Boolean = false,
    val verificationMessage: String? = null
)

class AuthViewModel(private val repository: Repository) : ViewModel() {

    private val _state = MutableStateFlow(AuthUiState())
    val state: StateFlow<AuthUiState> = _state.asStateFlow()

    fun clearFormMessages() {
        _state.value = _state.value.copy(error = null, verificationMessage = null)
    }

    fun login(username: String, password: String) = viewModelScope.launch {
        _state.value = _state.value.copy(isLoading = true, error = null, verificationMessage = null)
        try {
            repository.login(username, password)
            _state.value = _state.value.copy(isLoading = false, isLoggedIn = true)
        } catch (e: Exception) {
            val msg = when {
                e is HttpException && e.code() == 403 -> {
                    val body = e.response()?.errorBody()?.string().orEmpty()
                    if (body.contains("EMAIL_NOT_VERIFIED")) {
                        "Confirm your email before logging in. Check your inbox for the link."
                    } else {
                        "Invalid credentials"
                    }
                }
                else -> "Invalid credentials"
            }
            _state.value = _state.value.copy(isLoading = false, error = msg)
        }
    }

    fun signup(username: String, password: String, email: String) = viewModelScope.launch {
        _state.value = _state.value.copy(isLoading = true, error = null, verificationMessage = null)
        when {
            email.isBlank() -> {
                _state.value = _state.value.copy(isLoading = false, error = "Enter your email")
            }
            !email.contains("@") || !email.contains(".") -> {
                _state.value = _state.value.copy(isLoading = false, error = "Enter a valid email address")
            }
            else -> try {
                val (_, message) = repository.signup(username, password, email)
                _state.value = _state.value.copy(isLoading = false, isLoggedIn = false, verificationMessage = message)
            } catch (e: Exception) {
                val msg = when {
                    e is HttpException && e.code() == 409 -> {
                        val body = e.response()?.errorBody()?.string().orEmpty()
                        when {
                            body.contains("EMAIL_TAKEN") -> "That email is already registered"
                            body.contains("USERNAME_TAKEN") -> "Username already taken"
                            else -> "Username or email already taken"
                        }
                    }
                    else -> "Signup failed"
                }
                _state.value = _state.value.copy(isLoading = false, error = msg)
            }
        }
    }
}
