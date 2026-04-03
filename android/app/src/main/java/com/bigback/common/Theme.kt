package com.maillardmap.common

import androidx.compose.foundation.layout.*
import androidx.compose.material.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color

val BigBackPrimary = Color(0xFFFF6B35)
val BigBackSurface = Color(0xFFF5F5F5)

private val LightColors = lightColors(
    primary = BigBackPrimary,
    secondary = Color(0xFF4A90D9),
    surface = BigBackSurface,
    background = Color.White
)

@Composable
fun BigBackTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colors = LightColors,
        content = content
    )
}

@Composable
fun PreviewTheme(content: @Composable () -> Unit) {
    BigBackTheme {
        Surface(
            modifier = Modifier.fillMaxSize(),
            color = MaterialTheme.colors.background
        ) {
            content()
        }
    }
}
