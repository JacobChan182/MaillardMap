package com.bigback.ui.auth

import android.content.Context
import androidx.compose.foundation.layout.*
import androidx.compose.material.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.bigback.common.PreviewTheme
import com.bigback.data.RetrofitClient
import com.bigback.data.SessionManager
import com.bigback.data.Repository
import com.bigback.data.BigBackApi
import kotlinx.coroutines.flow.collectLatest

@Composable
fun AuthScreen(onAuthSuccess: () -> Unit) {
    val context = androidx.compose.ui.platform.LocalContext.current
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
            if (s.isLoggedIn) {
                onAuthSuccess()
            }
        }
    }

    PreviewTheme {
        AuthenticationForm(
            onLogin = { phoneOrEmail, pass -> vm.login(phoneOrEmail, pass) },
            onSignup = { user, phoneOrEmail, pass -> vm.signup(user, phoneOrEmail, pass) },
            isLoading = state.isLoading,
            errorMessage = state.error
        )
    }
}

@Composable
private fun AuthenticationForm(
    onLogin: (String, String) -> Unit,
    onSignup: (String, String, String) -> Unit,
    isLoading: Boolean,
    errorMessage: String?
) {
    var isLogin by remember { mutableStateOf(true) }
    var username by remember { mutableStateOf("") }
    var phoneOrEmail by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.Center
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Icon(
                imageVector = androidx.compose.material.icons.Icons.Default.Restaurant,
                contentDescription = null,
                modifier = Modifier.size(80.dp),
                tint = MaterialTheme.colors.primary
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "BigBack",
                style = MaterialTheme.typography.h4,
                color = MaterialTheme.colors.primary
            )
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

            OutlinedTextField(
                value = phoneOrEmail,
                onValueChange = { phoneOrEmail = it },
                label = { Text("Phone or Email") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth()
            )

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
                    if (phoneOrEmail.isNotBlank() && password.isNotBlank() && (!isLogin || username.isNotBlank())) {
                        if (isLogin) onLogin(phoneOrEmail, password)
                        else onSignup(username, phoneOrEmail, password)
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
                Text(
                    text = errorMessage,
                    color = MaterialTheme.colors.error,
                    style = MaterialTheme.typography.body2
                )
            }

            Spacer(modifier = Modifier.height(12.dp))

            TextButton(
                onClick = {
                    isLogin = !isLogin
                    errorMessage?.let { }
                },
                modifier = Modifier.align(Alignment.CenterHorizontally)
            ) {
                Text(
                    text = if (isLogin) "Already have an account? Log in"
                    else "Don't have an account? Sign up",
                    color = android.graphics.Color.parseColor("#2196F3"),
                    style = MaterialTheme.typography.caption
                )
            }
        }
    }
}
