package com.kumarabd.missioncontrol.media

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/** A bearer token is kept only in process memory, never in the briefing cache. */
object BriefingAccess {
    @Volatile
    private var token: String? = null

    fun update(value: String) {
        token = value
    }

    fun authorizationHeader(): String? = token?.let { "Bearer $it" }
}

class BriefingGateway(
    private val context: Context,
    routerBaseUrl: String,
) {
    private val gatewayBaseUrl = "${routerBaseUrl.trimEnd('/')}/gateway"

    suspend fun refresh(token: String): Int = withContext(Dispatchers.IO) {
        val connection = (URL("$gatewayBaseUrl/android/briefings").openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            setRequestProperty("Authorization", "Bearer $token")
            setRequestProperty("Accept", "application/json")
            connectTimeout = 15_000
            readTimeout = 15_000
        }

        try {
            if (connection.responseCode !in 200..299) {
                throw IllegalStateException("Gateway returned HTTP ${connection.responseCode}")
            }
            val payload = connection.inputStream.bufferedReader().use { it.readText() }
            val items = JSONObject(payload).getJSONArray("briefings")
            val briefings = List(items.length()) { index ->
                val item = items.getJSONObject(index)
                BriefingCatalog.Briefing(
                    id = item.getLong("turn_seq").toString(),
                    title = item.getString("title"),
                    summary = item.getString("summary"),
                    audioUrl = mediaUrl(item.getString("audio_path")),
                    publishedAtEpochMs = item.getString("published_at").let(::parseTimestamp),
                )
            }
            BriefingCatalog(context).replace(briefings)
            BriefingAccess.update(token)
            briefings.size
        } finally {
            connection.disconnect()
        }
    }

    private fun parseTimestamp(value: String): Long = runCatching {
        java.time.Instant.parse(value).toEpochMilli()
    }.getOrDefault(System.currentTimeMillis())

    private fun mediaUrl(path: String): String = runCatching {
        URL(path).takeIf { it.protocol == "http" || it.protocol == "https" }?.toString()
    }.getOrNull() ?: URL(
        URL("$gatewayBaseUrl/"),
        path.removePrefix("/").removePrefix("gateway/"),
    ).toString()
}
