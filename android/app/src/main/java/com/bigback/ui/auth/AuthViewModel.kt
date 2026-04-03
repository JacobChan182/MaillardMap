package com.maillardmap.ui.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.gson.Gson
import com.maillardmap.data.ApiErrorEnvelope
import com.maillardmap.data.Repository
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import retrofit2.HttpException

data class AuthUiState(
    val isLoading: Boolean = false,
    val error: String? = null,
    val isLoggedIn: Boolean = false,
    val verificationMessage: String? = null,
    val needsEmailVerificationFromLogin: Boolean = false,
    val resendCooldownSeconds: Int = 0
)

class AuthViewModel(private val repository: Repository) : ViewModel() {

    private val gson = Gson()
    private var resendCooldownJob: Job? = null

    private val _state = MutableStateFlow(AuthUiState())
    val state: StateFlow<AuthUiState> = _state.asStateFlow()

    fun resetVerificationUi() {
        resendCooldownJob?.cancel()
        resendCooldownJob = null
        _state.value = _state.value.copy(
            error = null,
            verificationMessage = null,
            needsEmailVerificationFromLogin = false,
            resendCooldownSeconds = 0
        )
    }

    fun login(username: String, password: String) = viewModelScope.launch {
        _state.value = _state.value.copy(
            isLoading = true,
            error = null,
            verificationMessage = null,
            needsEmailVerificationFromLogin = false
        )
        try {
            repository.login(username, password)
            _state.value = _state.value.copy(isLoading = false, isLoggedIn = true)
        } catch (e: Exception) {
            val apiField = parseApiErrorFromException(e)
            val msg = apiField?.message?.takeIf { it.isNotBlank() }
                ?: when {
                    e is HttpException && e.code() == 401 -> "Invalid credentials"
                    else -> "Something went wrong. Try again."
                }
            val needsVerify = apiField?.code == "EMAIL_NOT_VERIFIED"
            _state.value = _state.value.copy(
                isLoading = false,
                error = msg,
                needsEmailVerificationFromLogin = needsVerify
            )
            if (needsVerify) startResendCooldown()
        }
    }

    fun signup(username: String, password: String, email: String) = viewModelScope.launch {
        _state.value = _state.value.copy(
            isLoading = true,
            error = null,
            verificationMessage = null,
            needsEmailVerificationFromLogin = false
        )
        when {
            email.isBlank() -> {
                _state.value = _state.value.copy(isLoading = false, error = "Enter your email")
            }
            !email.contains("@") || !email.contains(".") -> {
                _state.value = _state.value.copy(isLoading = false, error = "Enter a valid email address")
            }
            else -> try {
                val (_, message) = repository.signup(username, password, email)
                _state.value = _state.value.copy(
                    isLoading = false,
                    isLoggedIn = false,
                    verificationMessage = message
                )
                startResendCooldown()
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
                    else -> parseApiErrorFromException(e)?.message?.takeIf { it.isNotBlank() } ?: "Signup failed"
                }
                _state.value = _state.value.copy(isLoading = false, error = msg)
            }
        }
    }

    fun resendConfirmation(username: String) = viewModelScope.launch {
        val id = username.trim()
        if (id.length < 3) {
            _state.value = _state.value.copy(error = "Enter the username or email you used to sign up.")
            return@launch
        }
        if (_state.value.resendCooldownSeconds > 0) return@launch
        _state.value = _state.value.copy(isLoading = true, error = null)
        try {
            val msg = repository.resendConfirmation(id)
            _state.value = _state.value.copy(isLoading = false, verificationMessage = msg)
        } catch (e: Exception) {
            val m = parseApiErrorFromException(e)?.message?.takeIf { it.isNotBlank() }
                ?: "Could not resend confirmation email."
            _state.value = _state.value.copy(isLoading = false, error = m)
        }
        startResendCooldown()
    }

    private fun startResendCooldown() {
        resendCooldownJob?.cancel()
        resendCooldownJob = viewModelScope.launch {
            var sec = 30
            while (sec >= 0) {
                _state.value = _state.value.copy(resendCooldownSeconds = sec)
                if (sec == 0) break
                delay(1000)
                sec--
            }
        }
    }

    private fun parseApiErrorFromException(e: Exception) =
        (e as? HttpException)?.let { http ->
            try {
                val raw = http.response()?.errorBody()?.string().orEmpty()
                if (raw.isBlank()) null
                else gson.fromJson(raw, ApiErrorEnvelope::class.java)?.error
            } catch (_: Exception) {
                null
            }
        }

    override fun onCleared() {
        super.onCleared()
        resendCooldownJob?.cancel()
    }
}
