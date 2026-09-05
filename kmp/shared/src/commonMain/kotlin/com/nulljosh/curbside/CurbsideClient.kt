package com.nulljosh.curbside

import io.ktor.client.HttpClient
import io.ktor.client.plugins.HttpTimeout
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.request.get
import io.ktor.client.statement.bodyAsText
import io.ktor.http.encodeURLParameter
import io.ktor.http.encodeURLPathPart
import io.ktor.serialization.kotlinx.json.json
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

@Serializable
data class Listing(
    val id: Long? = null,
    val uuid: String? = null,
    val title: String = "",
    val priceString: String? = null,
    val location: String? = null,
    val postedDate: Long? = null,
    val thumb: String? = null,
    val images: List<String> = emptyList(),
    val url: String? = null,
)

@Serializable
private data class SearchLocation(val city: String? = null)

@Serializable
private data class SearchResponse(
    val items: List<Listing> = emptyList(),
    val total: Int = 0,
    val location: SearchLocation? = null,
    val error: String? = null,
)

data class SearchFilters(
    val query: String = "",
    val category: String = "sss",
    val city: String = "vancouver",
    val minPrice: String = "",
    val maxPrice: String = "",
    val hasPhoto: Boolean = false,
    val sort: String = "rel",
)

data class SearchResult(val items: List<Listing>, val total: Int, val cityName: String?)

val CATEGORIES = listOf(
    "sss" to "For sale", "hhh" to "Housing", "apa" to "Apartments / housing",
    "bbb" to "Jobs (all)", "jjj" to "Jobs", "ggg" to "Gigs",
    "cta" to "Cars & trucks", "ccc" to "Community", "rrr" to "Resumes",
)

/**
 * Thin fetch against the curbside-api Worker -- the same JSON endpoint the web app calls.
 * The decode logic (worker/decode.js) lives server-side; nothing here reimplements it.
 */
class CurbsideClient(private val http: HttpClient = defaultClient()) {

    companion object {
        private const val API = "https://curbside-api.trommatic.workers.dev"
        private val lenientJson = Json { ignoreUnknownKeys = true; isLenient = true }

        fun defaultClient(): HttpClient = HttpClient {
            install(ContentNegotiation) { json(lenientJson) }
            install(HttpTimeout) {
                requestTimeoutMillis = 10_000
                connectTimeoutMillis = 10_000
            }
        }
    }

    suspend fun search(f: SearchFilters): Result<SearchResult> = runCatching {
        val params = buildList {
            add("city=${f.city.encodeURLParameter()}")
            add("cat=${f.category.encodeURLParameter()}")
            if (f.query.isNotBlank()) add("q=${f.query.encodeURLParameter()}")
            if (f.minPrice.isNotBlank()) add("min_price=${f.minPrice}")
            if (f.maxPrice.isNotBlank()) add("max_price=${f.maxPrice}")
            if (f.hasPhoto) add("hasPic=1")
            if (f.sort != "rel") add("sort=${f.sort}")
        }.joinToString("&")

        val text = http.get("$API/api/search?$params").bodyAsText()
        val d = lenientJson.decodeFromString<SearchResponse>(text)
        if (d.error != null) throw IllegalStateException(d.error)
        SearchResult(d.items, d.total, d.location?.city)
    }
}

expect fun currentTimeSeconds(): Long

fun agoText(secs: Long?): String {
    if (secs == null) return ""
    val m = maxOf(0, (currentTimeSeconds() - secs) / 60)
    return when {
        m < 60 -> "${m}m ago"
        m < 1440 -> "${m / 60}h ago"
        else -> "${m / 1440}d ago"
    }
}
