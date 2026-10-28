package org.nighthawklabs.missioncontrol.core.assistant

import android.content.Context
import android.content.SharedPreferences
import com.clerk.api.Clerk
import com.clerk.api.network.serialization.ClerkResult
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import org.json.JSONObject
import java.util.UUID
import kotlin.math.min
import kotlin.random.Random

/**
 * Realtime connection for one person-initiated assistant turn.
 *
 * A visible dashboard deliberately does not imply a live connection. The socket
 * exists only for an interaction in progress. A user-started hands-free session
 * may keep that interaction alive while the phone Activity is backgrounded.
 */
class AssistantGateway(
    private val scope: CoroutineScope,
    private val tokenProvider: GatewaySessionTokenProvider,
    private val eventListener: (GatewayEvent) -> Unit,
    private val client: OkHttpClient = OkHttpClient(),
    private val endpoint: String = DEFAULT_ENDPOINT,
    private val deviceId: String,
    private val cursorStore: GatewayCursorStore,
) {
    private var appForeground = false
    private var interactionActive = false
    private var socket: WebSocket? = null
    private var reconnectJob: Job? = null
    private var retryDelayMs = 1_000L
    private var intentionallyClosed = false
    private var isReady = false
    private var outboundTurnAwaitingStart = false
    private var activeTurnSequence: Long? = null
    private val queuedFrames = mutableListOf<String>()

    fun setAppForeground(isForeground: Boolean) {
        appForeground = isForeground
        if (isForeground) connectIfNeeded() else closeTransport()
    }

    fun beginInteraction() {
        interactionActive = true
        intentionallyClosed = false
        connectIfNeeded()
    }

    fun endInteraction() {
        interactionActive = false
        closeTransport()
    }

    fun sendMessage(text: String) {
        if (text.isBlank()) return
        beginInteraction()
        val clientMessageId = UUID.randomUUID().toString()
        enqueue(
            JSONObject()
                .put("type", "message")
                .put("client_msg_id", clientMessageId)
                .put("text", text)
                .put("mode", "voice")
                .put("device_id", deviceId)
                .toString(),
        )
    }

    private val shouldMaintainConnection: Boolean
        get() = appForeground && interactionActive

    private fun connectIfNeeded() {
        if (!shouldMaintainConnection || socket != null) return

        scope.launch {
            eventListener(GatewayEvent.Connecting)
            val token = tokenProvider.sessionToken()
            if (token.isNullOrBlank()) {
                eventListener(GatewayEvent.AuthenticationRequired)
                endInteraction()
                return@launch
            }
            if (!shouldMaintainConnection || socket != null) return@launch

            val request = Request.Builder().url(endpoint).build()
            socket = client.newWebSocket(request, listener(token))
        }
    }

    private fun listener(token: String) = object : WebSocketListener() {
        override fun onOpen(webSocket: WebSocket, response: Response) {
            val auth = JSONObject()
                .put("type", "auth")
                .put("token", token)
                .put("device_id", deviceId)
            cursorStore.completedTurnSequence?.let { auth.put("after_turn_seq", it) }
            webSocket.send(auth.toString())
        }

        override fun onMessage(webSocket: WebSocket, text: String) {
            val frame = runCatching { JSONObject(text) }.getOrNull() ?: return
            when (frame.optString("type")) {
                "turn_start" -> {
                    val turnSequence = frame.turnSequence() ?: return
                    // History is received before queued outbound work flushes. Only a
                    // turn started after this client actually sent a message is live.
                    if (outboundTurnAwaitingStart) {
                        outboundTurnAwaitingStart = false
                        activeTurnSequence = turnSequence
                        eventListener(GatewayEvent.TurnStarted(turnSequence))
                    }
                }
                "resumed" -> {
                    isReady = true
                    retryDelayMs = 1_000L
                    eventListener(GatewayEvent.Ready)
                    flushQueuedFrames()
                }
                "delta" -> if (frame.turnSequence() == activeTurnSequence) {
                    eventListener(
                        GatewayEvent.Delta(
                            text = frame.optString("text"),
                            replace = frame.optBoolean("replace", false),
                            progress = frame.optBoolean("progress", false),
                        ),
                    )
                }
                "turn_end" -> {
                    val turnSequence = frame.turnSequence() ?: return
                    cursorStore.saveCompletedTurn(turnSequence)
                    if (turnSequence == activeTurnSequence) {
                        activeTurnSequence = null
                        eventListener(GatewayEvent.TurnFinished)
                        endInteraction()
                    }
                }
                "error" -> eventListener(GatewayEvent.Error(frame.optString("message", "Assistant connection failed.")))
            }
        }

        override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
            webSocket.close(code, reason)
        }

        override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
            handleTransportClosed(webSocket)
        }

        override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
            handleTransportClosed(webSocket)
        }
    }

    private fun enqueue(frame: String) {
        val activeSocket = socket
        if (isReady && activeSocket != null) {
            if (activeSocket.send(frame)) markOutboundTurn(frame)
            else queuedFrames += frame
        }
        else {
            queuedFrames += frame
            connectIfNeeded()
        }
    }

    private fun flushQueuedFrames() {
        val activeSocket = socket ?: return
        val frames = queuedFrames.toList()
        queuedFrames.clear()
        frames.forEach { frame ->
            if (activeSocket.send(frame)) markOutboundTurn(frame) else queuedFrames += frame
        }
    }

    private fun markOutboundTurn(frame: String) {
        if (runCatching { JSONObject(frame).optString("type") }.getOrNull() == "message") {
            outboundTurnAwaitingStart = true
        }
    }

    private fun handleTransportClosed(closedSocket: WebSocket) {
        if (socket !== closedSocket) return
        socket = null
        isReady = false
        scheduleReconnect()
    }

    private fun scheduleReconnect() {
        if (!shouldMaintainConnection || intentionallyClosed || reconnectJob != null) return
        val delayMs = min(30_000L, retryDelayMs) + Random.nextLong(0, 1_000)
        retryDelayMs = min(30_000L, retryDelayMs * 2)
        reconnectJob = scope.launch {
            delay(delayMs)
            reconnectJob = null
            connectIfNeeded()
        }
    }

    private fun closeTransport() {
        intentionallyClosed = true
        isReady = false
        reconnectJob?.cancel()
        reconnectJob = null
        socket?.close(GOING_AWAY, "Interaction complete")
        socket = null
    }

    companion object {
        private const val GOING_AWAY = 1001
        private const val DEFAULT_ENDPOINT = "wss://api.nighthawklabs.org/gateway/android/ws"

        fun deviceId(context: Context): String {
            val preferences = context.getSharedPreferences("assistant_gateway", Context.MODE_PRIVATE)
            return preferences.getString("device_id", null)
                ?: UUID.randomUUID().toString().also { preferences.edit().putString("device_id", it).apply() }
        }
    }
}

private fun JSONObject.turnSequence(): Long? = optLong("turn_seq", -1L).takeIf { it >= 0L }

class GatewayCursorStore(context: Context) {
    private val preferences: SharedPreferences = context.getSharedPreferences("assistant_gateway", Context.MODE_PRIVATE)

    var completedTurnSequence: Long?
        get() = preferences.takeIf { it.contains(COMPLETED_TURN_KEY) }?.getLong(COMPLETED_TURN_KEY, 0L)
        private set(value) {
            preferences.edit().apply {
                if (value == null) remove(COMPLETED_TURN_KEY) else putLong(COMPLETED_TURN_KEY, value)
            }.apply()
        }

    fun saveCompletedTurn(turnSequence: Long) {
        if (turnSequence > (completedTurnSequence ?: -1L)) completedTurnSequence = turnSequence
    }

    private companion object {
        // Do not inherit the cursor from the former shared-mobile history.
        const val COMPLETED_TURN_KEY = "android_completed_turn_sequence_v1"
    }
}

sealed interface GatewayEvent {
    data class TurnStarted(val turnSequence: Long) : GatewayEvent
    data object Connecting : GatewayEvent
    data object Ready : GatewayEvent
    data object TurnFinished : GatewayEvent
    data object AuthenticationRequired : GatewayEvent
    data class Delta(val text: String, val replace: Boolean, val progress: Boolean) : GatewayEvent
    data class Error(val message: String) : GatewayEvent
}

/** Keep authentication at the application boundary; a Clerk implementation plugs in here later. */
fun interface GatewaySessionTokenProvider {
    suspend fun sessionToken(): String?
}

object UnconfiguredGatewaySessionTokenProvider : GatewaySessionTokenProvider {
    override suspend fun sessionToken(): String? = null
}

/** Retrieves a short-lived Clerk session token only when an assistant turn starts. */
object ClerkGatewaySessionTokenProvider : GatewaySessionTokenProvider {
    override suspend fun sessionToken(): String? = when (val result = Clerk.auth.getToken()) {
        is ClerkResult.Success -> result.value
        is ClerkResult.Failure -> null
    }
}
