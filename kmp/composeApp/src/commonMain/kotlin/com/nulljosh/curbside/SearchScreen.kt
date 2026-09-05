package com.nulljosh.curbside

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch

// Curbside's own rust-orange, matching web/index.html's --curb token.
private val Curb = Color(0xCC, 0x52, 0x00)

@Composable
fun SearchScreen(modifier: Modifier = Modifier) {
    val client = remember { CurbsideClient() }
    val scope = rememberCoroutineScope()

    var query by remember { mutableStateOf("") }
    var city by remember { mutableStateOf("vancouver") }
    var results by remember { mutableStateOf<List<Listing>>(emptyList()) }
    var status by remember { mutableStateOf("Search to begin.") }
    var loading by remember { mutableStateOf(false) }

    fun submit() {
        loading = true
        status = "Searching…"
        scope.launch {
            client.search(SearchFilters(query = query.trim(), city = city.trim().ifBlank { "vancouver" }))
                .onSuccess { r ->
                    results = r.items
                    status = if (r.total > 0) "${r.total} results in ${r.cityName ?: city}" else "No results."
                }
                .onFailure { status = "Couldn't reach the server." }
            loading = false
        }
    }

    Column(modifier = modifier.fillMaxSize().padding(20.dp)) {
        Text("Curbside", fontSize = 22.sp, fontWeight = FontWeight.Bold, color = Curb)
        Spacer(Modifier.height(16.dp))

        Row {
            OutlinedTextField(
                value = query,
                onValueChange = { query = it },
                placeholder = { Text("Search listings") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                keyboardActions = KeyboardActions(onSearch = { submit() }),
                modifier = Modifier.weight(1f),
            )
            Spacer(Modifier.width(8.dp))
            OutlinedTextField(
                value = city,
                onValueChange = { city = it },
                placeholder = { Text("City") },
                singleLine = true,
                modifier = Modifier.width(140.dp),
            )
            Spacer(Modifier.width(8.dp))
            Button(onClick = { submit() }) { Text("Search") }
        }

        Spacer(Modifier.height(12.dp))
        Text(status, fontSize = 13.sp, color = Color.Gray)
        Spacer(Modifier.height(8.dp))

        if (loading) {
            CircularProgressIndicator(color = Curb)
        } else {
            LazyColumn(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                items(results) { listing -> ListingRow(listing) }
            }
        }
    }
}

@Composable
private fun ListingRow(listing: Listing) {
    Column(Modifier.fillMaxWidth().padding(vertical = 8.dp)) {
        Row {
            Text(listing.priceString ?: "—", fontWeight = FontWeight.Bold, color = Curb)
            Spacer(Modifier.width(8.dp))
            Text(listing.title, fontSize = 14.sp)
        }
        Text(
            listOfNotNull(listing.location, agoText(listing.postedDate)).joinToString(" · "),
            fontSize = 12.sp,
            color = Color.Gray,
        )
    }
    HorizontalDivider()
}
