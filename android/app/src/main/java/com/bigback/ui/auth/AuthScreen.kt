package com.bigback.ui.auth

import androidx.compose.foundation.layout.*
import androidx.compose.material.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.bigback.common.BigBackTheme
import com.bigback.data.*
import kotlinx.coroutines.flow.collectLatest

@Composable
fun AuthScreen(onAuthSuccess: () -> Unit) {
    val context = LocalContext.current
    val vm: AuthViewModel = viewModel(
        factory = object : androidx.lifecycle.ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T : androidx.lifecycle.ViewModel> create(modelClass: Class<T>): T {
                val sessionManager = SessionManager(context)
                val okHttp = RetrofitClient.okHttpClient(sessionManager)
                val api = RetrofitClient.create(okHttp, "http://10.0.2.2:3000/")
                val repository = Repository(api, sessionManager)
                return AuthViewModel(repository) as T
            }
        }
    )

    val state by vm.state.collectAsState()

    LaunchedEffect(Unit) {
        vm.state.collectLatest { s ->
            if (s.isLoggedIn) onAuthSuccess()
        }
    }

    BigBackTheme {
        AuthenticationForm(
            onLogin = { user, pass -> vm.login(user, pass) },
            onSignup = { user, pass -> vm.signup(user, pass) },
            isLoading = state.isLoading,
            errorMessage = state.error
        )
    }
}

@Composable
private fun AuthenticationForm(
    onLogin: (String, String) -> Unit,
    onSignup: (String, String) -> Unit,
    isLoading: Boolean,
    errorMessage: String?
) {
    var isLogin by remember { mutableStateOf(true) }
    var username by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }

    Column(
        modifier = Modifier.fillMaxSize().padding(24.dp),
        verticalArrangement = Arrangement.Center
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Icon(
                imageVector = Icons.Default.Restaurant,
                contentDescription = null,
                modifier = Modifier.size(80.dp),
                tint = MaterialTheme.colors.primary
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(text = "BigBack", style = MaterialTheme.typography.h4, color = MaterialTheme.colors.primary)
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = if (isLogin) "Share your taste. Blend with friends." else "Create your account",
                style = MaterialTheme.typography.subtitle1,
                color = MaterialTheme.colors.onSurface.copy(alpha = 0.5f)
            )
        }

        Spacer(modifier = Modifier.height(40.dp))

        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            if (!isLogin) {
                OutlinedTextField(
                    value = username,
                    onValueChange = { username = it },
                    label = { Text("Username") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
            }

            if (isLogin) {
                OutlinedTextField(
                    value = username,
                    onValueChange = { username = it },
                    label = { Text("Username") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
            }

            OutlinedTextField(
                value = password,
                onValueChange = { password = it },
                label = { Text("Password") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                visualTransformation = PasswordVisualTransformation()
            )

            Spacer(modifier = Modifier.height(12.dp))

            Button(
                onClick = {
                    if (username.isNotBlank() && password.isNotBlank()) {
                        if (isLogin) onLogin(username, password)
                        else onSignup(username, password)
                    }
                },
                modifier = Modifier.fillMaxWidth(),
                enabled = !isLoading
            ) {
                if (isLoading) {
                    CircularProgressIndicator(
                        color = MaterialTheme.colors.onPrimary,
                        modifier = Modifier.size(24.dp)
                    )
                } else {
                    Text(if (isLogin) "Log In" else "Sign Up")
                }
            }

            if (errorMessage != null) {
                Text(text = errorMessage, color = MaterialTheme.colors.error, style = MaterialTheme.typography.body2)
            }

            TextButton(
                onClick = { isLogin = !isLogin },
                modifier = Modifier.align(Alignment.CenterHorizontally)
            ) {
                Text(
                    text = if (isLogin) "Don't have an account? Sign up" else "Already have an account? Log in",
                    color = MaterialTheme.colors.primary,
                    style = MaterialTheme.typography.caption
                )
            }
        }
    }
}
