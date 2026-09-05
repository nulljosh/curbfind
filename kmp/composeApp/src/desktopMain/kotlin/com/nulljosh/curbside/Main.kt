package com.nulljosh.curbside

import androidx.compose.material3.MaterialTheme
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Window
import androidx.compose.ui.window.application
import androidx.compose.ui.window.rememberWindowState

fun main() = application {
    Window(
        onCloseRequest = ::exitApplication,
        title = "Curbside",
        state = rememberWindowState(size = DpSize(900.dp, 700.dp)),
    ) {
        MaterialTheme { SearchScreen() }
    }
}
