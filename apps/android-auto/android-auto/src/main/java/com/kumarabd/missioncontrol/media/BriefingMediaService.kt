package com.kumarabd.missioncontrol.media

import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.ResolvingDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.session.LibraryResult
import androidx.media3.session.MediaLibraryService
import androidx.media3.session.MediaLibraryService.MediaLibrarySession
import androidx.media3.session.MediaSession
import com.google.common.collect.ImmutableList
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture
import com.clerk.api.Clerk
import com.clerk.api.network.serialization.successOrNull
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

/**
 * Android Auto discovers this service and renders its own safe media UI.
 * It never exposes gateway prompts, tools, account setup, or free-form chat.
 */
class BriefingMediaService : MediaLibraryService() {
    private lateinit var player: ExoPlayer
    private lateinit var session: MediaLibrarySession
    private lateinit var catalog: BriefingCatalog
    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onCreate() {
        super.onCreate()
        catalog = BriefingCatalog(this)
        val sourceFactory = DefaultMediaSourceFactory(
            ResolvingDataSource.Factory(DefaultHttpDataSource.Factory()) { dataSpec ->
                BriefingAccess.authorizationHeader()?.let { header ->
                    dataSpec.withRequestHeaders(mapOf("Authorization" to header))
                } ?: dataSpec
            }
        )
        player = ExoPlayer.Builder(this).setMediaSourceFactory(sourceFactory).build().apply {
            repeatMode = Player.REPEAT_MODE_OFF
        }
        session = MediaLibrarySession.Builder(this, player, BriefingCallback()).build()
        serviceScope.launch {
            Clerk.isInitialized.filter { it }.first()
            Clerk.auth.getToken().successOrNull()?.let(BriefingAccess::update)
        }
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaLibrarySession = session

    override fun onDestroy() {
        session.release()
        player.release()
        super.onDestroy()
    }

    private inner class BriefingCallback : MediaLibrarySession.Callback {
        override fun onGetLibraryRoot(
            session: MediaLibrarySession,
            browser: MediaSession.ControllerInfo,
            params: LibraryParams?,
        ): ListenableFuture<LibraryResult<MediaItem>> = Futures.immediateFuture(
            LibraryResult.ofItem(
                MediaItem.Builder()
                    .setMediaId(ROOT_ID)
                    .setMediaMetadata(
                        androidx.media3.common.MediaMetadata.Builder()
                            .setTitle("Mission Control briefings")
                            .setIsBrowsable(true)
                            .setIsPlayable(false)
                            .build()
                    )
                    .build(),
                params,
            )
        )

        override fun onGetChildren(
            session: MediaLibrarySession,
            browser: MediaSession.ControllerInfo,
            parentId: String,
            page: Int,
            pageSize: Int,
            params: LibraryParams?,
        ): ListenableFuture<LibraryResult<ImmutableList<MediaItem>>> {
            if (parentId != ROOT_ID) {
                return Futures.immediateFuture(LibraryResult.ofError(LibraryResult.RESULT_ERROR_BAD_VALUE))
            }
            return Futures.immediateFuture(
                LibraryResult.ofItemList(ImmutableList.copyOf(catalog.items()), params)
            )
        }

        override fun onAddMediaItems(
            mediaSession: MediaSession,
            controller: MediaSession.ControllerInfo,
            mediaItems: List<MediaItem>,
        ): ListenableFuture<List<MediaItem>> {
            val availableById = catalog.items().associateBy { it.mediaId }
            val resolved = mediaItems.mapNotNull { item -> availableById[item.mediaId] }
            return Futures.immediateFuture(resolved)
        }
    }

    private companion object {
        const val ROOT_ID = "mission-control-briefings"
    }
}
