package org.nighthawklabs.missioncontrol.feature.dashboard

import android.app.Application
import android.content.Context
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.nighthawklabs.missioncontrol.core.assistant.AssistantGateway
import org.nighthawklabs.missioncontrol.core.assistant.GatewayEvent
import org.nighthawklabs.missioncontrol.core.assistant.GatewayCursorStore
import org.nighthawklabs.missioncontrol.core.assistant.ClerkGatewaySessionTokenProvider
import org.nighthawklabs.missioncontrol.core.voice.AndroidVoiceCoordinator
import org.nighthawklabs.missioncontrol.core.voice.HandsFreeVoiceService
import org.nighthawklabs.missioncontrol.core.voice.VoiceEvent

class DashboardViewModel(application: Application) : AndroidViewModel(application) {
    private val _uiState = MutableStateFlow(AssistantUiState.idle())
    val uiState: StateFlow<AssistantUiState> = _uiState.asStateFlow()
    private val displayPreferences = application.getSharedPreferences(DISPLAY_PREFERENCES, Context.MODE_PRIVATE)
    private val _showConversationText = MutableStateFlow(
        displayPreferences.getBoolean(SHOW_CONVERSATION_TEXT_KEY, true),
    )
    val showConversationText: StateFlow<Boolean> = _showConversationText.asStateFlow()
    private val _handsFreeEnabled = MutableStateFlow(
        displayPreferences.getBoolean(HANDS_FREE_ENABLED_KEY, true),
    )
    val handsFreeEnabled: StateFlow<Boolean> = _handsFreeEnabled.asStateFlow()

    private val gateway = AssistantGateway(
        scope = viewModelScope,
        tokenProvider = ClerkGatewaySessionTokenProvider,
        eventListener = ::handleGatewayEvent,
        deviceId = AssistantGateway.deviceId(application),
        cursorStore = GatewayCursorStore(application),
    )
    private val voice = AndroidVoiceCoordinator(application, ::handleVoiceEvent)
    private var responseText = ""
    private var transportBuffer = ""
    private var speechBuffer = ""
    private var suppressStreamingSpeech = false
    private var progressNarration = ""
    // STT remains armed during an assistant response for barge-in, so its
    // callbacks cannot themselves be used as the visible conversation state.
    // These flags give a submitted turn and local playback precedence.
    private var awaitingAssistantResponse = false
    private var assistantSpeechActive = false

    fun setAppForeground(isForeground: Boolean) {
        // The foreground service starts only from the explicit Talk action. Once
        // active, it preserves this user-started conversation through onStop.
        gateway.setAppForeground(isForeground || handsFreeSessionIsActive)
    }

    fun toggleConversationTextVisibility() {
        val show = !_showConversationText.value
        _showConversationText.value = show
        displayPreferences.edit().putBoolean(SHOW_CONVERSATION_TEXT_KEY, show).apply()
    }

    fun toggleHandsFree() {
        val enabled = !_handsFreeEnabled.value
        _handsFreeEnabled.value = enabled
        displayPreferences.edit().putBoolean(HANDS_FREE_ENABLED_KEY, enabled).apply()
        if (enabled && voice.isConversationActive) HandsFreeVoiceService.start(getApplication<Application>())
        if (!enabled) HandsFreeVoiceService.stop(getApplication<Application>())
    }

    fun startVoiceInteraction() {
        responseText = ""
        awaitingAssistantResponse = false
        assistantSpeechActive = false
        if (_handsFreeEnabled.value) HandsFreeVoiceService.start(getApplication<Application>())
        gateway.beginInteraction()
        voice.beginConversation()
    }

    fun stopOrInterruptAssistant() {
        if (voice.isConversationActive || _uiState.value.isInteracting) {
            awaitingAssistantResponse = false
            assistantSpeechActive = false
            voice.endConversation()
            gateway.endInteraction()
            HandsFreeVoiceService.stop(getApplication<Application>())
            _uiState.value = AssistantUiState.idle()
        }
    }

    fun microphoneAccessDenied() {
        _uiState.value = AssistantUiState.error("Allow microphone access to speak with your assistant.")
    }

    fun authenticationDidComplete() {
        _uiState.value = AssistantUiState.idle()
    }

    private fun handleGatewayEvent(event: GatewayEvent) {
        _uiState.value = when (event) {
            is GatewayEvent.TurnStarted -> {
                voice.stopSpeaking()
                awaitingAssistantResponse = true
                assistantSpeechActive = false
                responseText = ""
                transportBuffer = ""
                speechBuffer = ""
                clearProgressNarration()
                suppressStreamingSpeech = false
                AssistantUiState.processing(_uiState.value.transcript)
            }
            GatewayEvent.Connecting -> _uiState.value
            GatewayEvent.Ready -> if (awaitingAssistantResponse) {
                AssistantUiState.processing(_uiState.value.transcript)
            } else {
                AssistantUiState.ready()
            }
            is GatewayEvent.Delta -> {
                transportBuffer = if (event.replace) event.text else transportBuffer + event.text
                if (event.progress) {
                    // Progress contains internal agent work, including tool
                    // activity. It may remain visible, but never enters TTS.
                    progressNarration = transportBuffer
                    _uiState.value.copy(progress = progressNarration)
                } else {
                    val replacingProgress = progressNarration.isNotEmpty()
                    clearProgressNarration()
                    if (event.replace) {
                        if (replacingProgress) voice.stopSpeaking()
                        responseText = transportBuffer
                        speechBuffer = transportBuffer
                    } else {
                        responseText = transportBuffer
                        speechBuffer += event.text
                    }
                    if (!suppressStreamingSpeech) speakCompletedSentences()
                    _uiState.value.copy(reply = responseText, progress = "")
                }
            }
            GatewayEvent.TurnFinished -> {
                clearProgressNarration()
                if (!suppressStreamingSpeech) {
                    val remainder = speechBuffer.trim()
                    if (remainder.isNotEmpty()) voice.speakSentence(remainder)
                    speechBuffer = ""
                    voice.completeResponse()
                }
                when {
                    assistantSpeechActive -> AssistantUiState.responding(_uiState.value.transcript, responseText)
                    awaitingAssistantResponse -> AssistantUiState.processing(_uiState.value.transcript)
                    else -> _uiState.value.copy(reply = responseText, progress = "")
                }
            }
            GatewayEvent.AuthenticationRequired -> AssistantUiState.authenticationRequired()
            is GatewayEvent.Error -> {
                awaitingAssistantResponse = false
                assistantSpeechActive = false
                voice.endConversation()
                AssistantUiState.error(event.message)
            }
        }
    }

    private fun handleVoiceEvent(event: VoiceEvent) {
        _uiState.value = when (event) {
            VoiceEvent.Preparing -> AssistantUiState.preparing()
            VoiceEvent.Listening -> captureState()
            VoiceEvent.InterruptionCandidate -> {
                // The voice coordinator has paused locally and retained the
                // remaining reply. Keep accepting response deltas so they can
                // play if Android rejects the candidate as noise.
                awaitingAssistantResponse = false
                assistantSpeechActive = false
                AssistantUiState.listening(_uiState.value.transcript)
            }
            VoiceEvent.InterruptionRejected -> {
                assistantSpeechActive = true
                AssistantUiState.responding(_uiState.value.transcript, responseText)
            }
            VoiceEvent.Processing -> captureState()
            is VoiceEvent.PartialTranscription -> {
                if (awaitingAssistantResponse || assistantSpeechActive) captureState()
                else AssistantUiState.listening(event.text)
            }
            is VoiceEvent.Transcribed -> {
                // A final, non-empty transcript is the one event that becomes
                // an upstream message. Interrupt the old reply at that exact
                // boundary, never for local speech/noise observations.
                // The previous turn can still have late deltas even after its
                // local TTS queue reports idle. Keep those from restarting
                // playback until the gateway starts the submitted turn.
                suppressStreamingSpeech = true
                clearProgressNarration()
                awaitingAssistantResponse = true
                assistantSpeechActive = false
                voice.stopSpeaking()
                gateway.sendMessage(event.payload)
                AssistantUiState.processing(event.rawText)
            }
            VoiceEvent.Speaking -> {
                awaitingAssistantResponse = false
                assistantSpeechActive = true
                AssistantUiState.responding(_uiState.value.transcript, responseText)
            }
            // A completed reply does not end the explicitly-started conversation.
            // The microphone is already waiting for the next natural utterance.
            VoiceEvent.Idle -> {
                awaitingAssistantResponse = false
                assistantSpeechActive = false
                if (voice.isConversationActive) {
                    AssistantUiState.listening(_uiState.value.transcript)
                } else {
                    AssistantUiState.idle()
                }
            }
            is VoiceEvent.Error -> {
                awaitingAssistantResponse = false
                assistantSpeechActive = false
                clearProgressNarration()
                gateway.endInteraction()
                HandsFreeVoiceService.stop(getApplication<Application>())
                AssistantUiState.error(event.message)
            }
        }
    }

    override fun onCleared() {
        gateway.endInteraction()
        voice.release()
        HandsFreeVoiceService.stop(getApplication<Application>())
        super.onCleared()
    }

    private fun speakCompletedSentences() {
        while (true) {
            val boundary = speechBuffer.indexOfFirst { character -> character == '.' || character == '!' || character == '?' }
            if (boundary < 0) return
            val after = boundary + 1
            if (after < speechBuffer.length && !speechBuffer[after].isWhitespace()) return
            val sentence = speechBuffer.substring(0, after).trim()
            speechBuffer = speechBuffer.substring(after)
            if (sentence.isNotEmpty()) voice.speakSentence(sentence)
        }
    }

    private fun clearProgressNarration() {
        progressNarration = ""
    }

    private fun captureState(): AssistantUiState = when {
        assistantSpeechActive -> AssistantUiState.responding(_uiState.value.transcript, responseText)
        awaitingAssistantResponse -> AssistantUiState.processing(_uiState.value.transcript)
        else -> AssistantUiState.listening(_uiState.value.transcript)
    }

    private val handsFreeSessionIsActive: Boolean
        get() = _handsFreeEnabled.value && voice.isConversationActive

    private companion object {
        const val DISPLAY_PREFERENCES = "assistant_display"
        const val SHOW_CONVERSATION_TEXT_KEY = "show_conversation_text"
        const val HANDS_FREE_ENABLED_KEY = "hands_free_enabled"
    }
}

data class AssistantUiState(
    val isInteracting: Boolean,
    val primaryMessage: String,
    val secondaryMessage: String,
    val presence: AgentPresence = AgentPresence.IDLE,
    val requiresSignIn: Boolean = false,
    val transcript: String = "",
    val reply: String = "",
    val progress: String = "",
) {
    companion object {
        fun idle() = AssistantUiState(false, "Next · 2:30 PM · Dentist", "Leave in 20 minutes · tap Tasks for your full day")
        fun preparing() = AssistantUiState(true, "Waking Mission Control", "Preparing a private voice session.", AgentPresence.PREPARING)
        fun connecting() = AssistantUiState(true, "Opening your assistant channel…", "This connection ends when the turn is complete.", AgentPresence.THINKING)
        fun listening(transcript: String = "") = AssistantUiState(true, "Listening", "Hands-free continues while you leave the app. Tap the assistant to end.", AgentPresence.LISTENING, transcript = transcript)
        fun processing(transcript: String) = AssistantUiState(true, "Thinking", "Your words are on their way to your assistant.", AgentPresence.THINKING, transcript = transcript)
        fun responding(transcript: String, reply: String) = AssistantUiState(true, "Responding", "Tap the assistant to end the conversation.", AgentPresence.SPEAKING, transcript = transcript, reply = reply)
        fun completed(transcript: String, reply: String) = AssistantUiState(false, "Ready", "Tap the assistant to speak again.", AgentPresence.IDLE, transcript = transcript, reply = reply)
        fun ready() = AssistantUiState(true, "Assistant channel ready", "I’m listening for your next instruction.", AgentPresence.LISTENING)
        fun authenticationRequired() = AssistantUiState(false, "Sign in to connect the assistant", "Your account stays securely on this device.", requiresSignIn = true)
        fun error(message: String) = AssistantUiState(false, "Assistant unavailable", message, AgentPresence.UNAVAILABLE)
    }
}

enum class AgentPresence { IDLE, PREPARING, LISTENING, THINKING, SPEAKING, UNAVAILABLE }
