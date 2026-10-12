package com.kumarabd.missioncontrol.media

import android.content.Context
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import org.json.JSONArray
import org.json.JSONObject

/**
 * The phone app writes signed briefing URLs here after an authenticated sync.
 * The car service deliberately reads only that cached, audio-only projection.
 */
class BriefingCatalog(context: Context) {
    private val preferences = context.getSharedPreferences("briefing_catalog", Context.MODE_PRIVATE)

    fun items(): List<MediaItem> = runCatching {
        val raw = preferences.getString(KEY_ITEMS, "[]") ?: "[]"
        val array = JSONArray(raw)
        List(array.length()) { index -> array.getJSONObject(index).toMediaItem() }
    }.getOrDefault(emptyList())

    fun replace(items: List<Briefing>) {
        val serialized = JSONArray().apply {
            items.forEach { briefing -> put(briefing.toJson()) }
        }
        preferences.edit().putString(KEY_ITEMS, serialized.toString()).apply()
    }

    data class Briefing(
        val id: String,
        val title: String,
        val summary: String,
        val audioUrl: String,
        val publishedAtEpochMs: Long,
    ) {
        fun toMediaItem(): MediaItem = MediaItem.Builder()
            .setMediaId(id)
            .setUri(audioUrl)
            .setMediaMetadata(
                MediaMetadata.Builder()
                    .setTitle(title)
                    .setDescription(summary)
                    .setIsPlayable(true)
                    .setIsBrowsable(false)
                    .build()
            )
            .build()

        fun toJson(): JSONObject = JSONObject()
            .put("id", id)
            .put("title", title)
            .put("summary", summary)
            .put("audio_url", audioUrl)
            .put("published_at", publishedAtEpochMs)
    }

    private fun JSONObject.toMediaItem() = Briefing(
        id = getString("id"),
        title = getString("title"),
        summary = getString("summary"),
        audioUrl = getString("audio_url"),
        publishedAtEpochMs = getLong("published_at"),
    ).toMediaItem()

    private companion object {
        const val KEY_ITEMS = "items"
    }
}
