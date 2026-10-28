package org.nighthawklabs.missioncontrol.core.voice

import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Bundle
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Log
import java.util.ArrayDeque
import java.util.Locale
import java.util.UUID

/** Keeps microphone capture and speech playback on-device. */
class AndroidVoiceCoordinator(
    context: Context,
    private val listener: (VoiceEvent) -> Unit,
) {
    private val appContext = context.applicationContext
    private val mainHandler = Handler(Looper.getMainLooper())
    private var recognizer: SpeechRecognizer? = null
    private var recognizerListening = false
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var conversationActive = false
    private var conversationGeneration = 0
    private val pendingSpeech = ArrayDeque<String>()
    private var activeSpeech: ActiveSpeech? = null
    private var playbackPaused = false
    private var interruptionCandidatePending = false
    private var interruptionCandidateConfirmed = false
    private var pendingInterruptionCandidate: Runnable? = null

    val isConversationActive: Boolean get() = conversationActive

    init {
        tts = TextToSpeech(appContext) { status ->
            ttsReady = status == TextToSpeech.SUCCESS
            if (ttsReady) {
                tts?.language = Locale.getDefault()
                tts?.setSpeechRate(1.04f)
            }
        }.also { engine ->
            engine.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String) {
                    mainHandler.post {
                        if (activeSpeech?.utteranceId == utteranceId) {
                            trace("tts started")
                            emit(VoiceEvent.Speaking)
                        }
                    }
                }
                override fun onDone(utteranceId: String) {
                    trace("tts completed")
                    mainHandler.post { finishUtterance(utteranceId) }
                }
                @Deprecated("Deprecated in Java")
                override fun onError(utteranceId: String) {
                    trace("tts failed")
                    mainHandler.post { finishUtterance(utteranceId) }
                }
                override fun onError(utteranceId: String, errorCode: Int) {
                    trace("tts failed code=$errorCode")
                    mainHandler.post { finishUtterance(utteranceId) }
                }
                override fun onRangeStart(utteranceId: String, start: Int, end: Int, frame: Int) {
                    mainHandler.post { activeSpeech?.takeIf { it.utteranceId == utteranceId }?.offset = start }
                }
            })
        }
    }

    fun beginConversation() {
        if (conversationActive) return
        conversationActive = true
        conversationGeneration += 1
        trace("conversation started")
        val generation = conversationGeneration
        emit(VoiceEvent.Preparing)
        playStartupCue()
        // Let the short readiness cue finish before opening the local
        // recognizer. It prevents the cue from becoming a false barge-in while
        // keeping the delay well below a conversational beat.
        mainHandler.postDelayed({
            if (generation == conversationGeneration) startListening()
        }, STARTUP_CUE_DURATION_MS)
    }

    private fun startListening() {
        if (!conversationActive || recognizerListening) return
        cancelPendingInterruptionCandidate()
        interruptionCandidatePending = false
        interruptionCandidateConfirmed = false
        if (!SpeechRecognizer.isRecognitionAvailable(appContext)) {
            conversationActive = false
            emit(VoiceEvent.Error("Speech recognition isn’t available on this device."))
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            !SpeechRecognizer.isOnDeviceRecognitionAvailable(appContext)
        ) {
            conversationActive = false
            emit(VoiceEvent.Error("On-device speech recognition isn’t available on this phone."))
            return
        }
        val speechRecognizer = recognizer ?: SpeechRecognizer.createOnDeviceSpeechRecognizer(appContext).also {
            recognizer = it
            it.setRecognitionListener(recognitionListener)
            trace("recognizer created")
        }
        recognizerListening = true
        try {
            speechRecognizer.startListening(recognitionIntent())
            trace("recognizer listening started")
        } catch (error: RuntimeException) {
            // A recognizer that failed before entering its listening state cannot
            // be recovered reliably. Recreate it for the next attempt instead of
            // leaving the conversation in a permanently deaf state.
            recognizerListening = false
            resetRecognizer()
            trace("recognizer start failed: ${error.javaClass.simpleName}")
            conversationActive = false
            emit(VoiceEvent.Error("Speech recognition couldn’t start. Try again."))
            return
        }
        emit(VoiceEvent.Listening)
    }

    fun endConversation() {
        conversationActive = false
        conversationGeneration += 1
        cancelPendingInterruptionCandidate()
        recognizerListening = false
        recognizer?.cancel()
        resetRecognizer()
        stopSpeaking()
        trace("conversation ended")
        emit(VoiceEvent.Idle)
    }

    /** Adds one assistant sentence to the app-owned playback queue. */
    fun speakSentence(text: String) {
        val spokenText = text.trim()
        if (spokenText.isEmpty()) {
            emit(VoiceEvent.Idle)
            return
        }
        if (!ttsReady) {
            emit(VoiceEvent.Error("Text-to-speech is still preparing. Try again in a moment."))
            return
        }
        pendingSpeech.addLast(spokenText)
        startNextSpeech()
    }

    fun completeResponse() {
        if (!playbackPaused && activeSpeech == null && pendingSpeech.isEmpty()) emit(VoiceEvent.Idle)
    }

    fun release() {
        cancelPendingInterruptionCandidate()
        recognizerListening = false
        resetRecognizer()
        tts?.shutdown()
        tts = null
    }

    fun stopSpeaking() {
        playbackPaused = false
        activeSpeech = null
        pendingSpeech.clear()
        tts?.stop()
        trace("tts queue cleared")
    }

    private fun finishUtterance(utteranceId: String) {
        if (activeSpeech?.utteranceId != utteranceId) return
        activeSpeech = null
        startNextSpeech()
    }

    private val recognitionListener = object : RecognitionListener {
        override fun onReadyForSpeech(params: Bundle?) {
            trace("recognizer ready")
            emit(VoiceEvent.Listening)
        }
        override fun onBeginningOfSpeech() {
            // On-device recognizers can detect speech onset while TTS is still
            // audible but may not produce a usable partial until playback has
            // stopped. Stop playback immediately so the opening words are
            // captured; NO_MATCH still resumes the retained reply for
            // noise/false starts.
            trace("speech began")
            scheduleInterruptionCandidate("speech-onset")
        }
        override fun onRmsChanged(rmsdB: Float) = Unit
        override fun onBufferReceived(buffer: ByteArray?) = Unit
        override fun onEndOfSpeech() {
            trace("speech ended")
            emit(VoiceEvent.Processing)
        }
        override fun onPartialResults(partialResults: Bundle?) {
            val text = partialResults
                ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                ?.firstOrNull()
                ?.trim()
                .orEmpty()
            if (text.isNotEmpty()) {
                trace("partial received chars=${text.length}")
                emit(VoiceEvent.PartialTranscription(text))
                scheduleInterruptionCandidate("partial")
            }
        }
        override fun onEvent(eventType: Int, params: Bundle?) = Unit

        override fun onResults(results: Bundle?) {
            cancelPendingInterruptionCandidate()
            recognizerListening = false
            trace("recognizer final result")
            deliverFinalResult(results)
            restartListeningSoon()
        }

        override fun onError(error: Int) {
            cancelPendingInterruptionCandidate()
            recognizerListening = false
            trace("recognizer error=$error candidate=$interruptionCandidateConfirmed")
            val message = when (error) {
                SpeechRecognizer.ERROR_AUDIO -> "The microphone is unavailable."
                SpeechRecognizer.ERROR_NETWORK, SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Speech recognition needs a connection right now."
                SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Allow microphone access to speak with your assistant."
                SpeechRecognizer.ERROR_NO_MATCH, SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "I didn’t catch that. Try again."
                else -> "Speech recognition couldn’t start. Try again."
            }
            if (conversationActive && error in setOf(SpeechRecognizer.ERROR_NO_MATCH, SpeechRecognizer.ERROR_SPEECH_TIMEOUT)) {
                if (playbackPaused) resumeAfterFalseInterruption() else emit(VoiceEvent.Listening)
                restartListeningSoon()
            } else {
                conversationActive = false
                emit(VoiceEvent.Error(message))
            }
        }
    }

    private fun emit(event: VoiceEvent) {
        mainHandler.post { listener(event) }
    }

    private fun deliverFinalResult(results: Bundle?) {
        val text = results
            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            ?.firstOrNull()
            ?.trim()
            .orEmpty()
        val payload = VoiceTranscriptCleaner.clean(text)
        if (payload.isEmpty()) {
            trace("final result empty candidate=$interruptionCandidateConfirmed paused=$playbackPaused")
            if (playbackPaused) resumeAfterFalseInterruption() else emit(VoiceEvent.Listening)
        } else {
            // A real user utterance is the durable interruption boundary. The
            // coordinator has already retained the unplayed reply while it was
            // being checked; discard it only now.
            stopSpeaking()
            trace("final result committed chars=${payload.length}")
            emit(VoiceEvent.Transcribed(rawText = text, payload = payload))
        }
    }

    /**
     * Speech onset is available while the assistant is still playing, whereas
     * a local recognizer may not emit a partial until after playback has ceased.
     * Preserve and silence the unread reply immediately at onset; the short
     * confirmation window only decides whether to surface the interruption.
     * Android's final result either commits it or resumes the preserved reply.
     */
    private fun scheduleInterruptionCandidate(source: String) {
        if (interruptionCandidatePending || interruptionCandidateConfirmed || !hasSpeechToPause()) {
            trace("candidate ignored source=$source pending=$interruptionCandidatePending confirmed=$interruptionCandidateConfirmed speech=${hasSpeechToPause()}")
            return
        }
        interruptionCandidatePending = true
        trace("candidate scheduled source=$source")
        // Do not spend the confirmation window competing with the user's first
        // words. This remains recoverable because no final user turn is sent
        // unless Android later supplies a non-empty final result.
        pauseForPossibleInterruption()
        trace("candidate playback paused immediately")
        pendingInterruptionCandidate = Runnable {
            pendingInterruptionCandidate = null
            interruptionCandidatePending = false
            if (!conversationActive || interruptionCandidateConfirmed || !hasSpeechToPause()) {
                trace("candidate expired active=$conversationActive confirmed=$interruptionCandidateConfirmed speech=${hasSpeechToPause()}")
                return@Runnable
            }
            interruptionCandidateConfirmed = true
            trace("candidate confirmed")
            emit(VoiceEvent.InterruptionCandidate)
        }.also { mainHandler.postDelayed(it, INTERRUPTION_CONFIRMATION_MS) }
    }

    private fun cancelPendingInterruptionCandidate() {
        pendingInterruptionCandidate?.let(mainHandler::removeCallbacks)
        pendingInterruptionCandidate = null
        interruptionCandidatePending = false
    }

    private fun resetRecognizer() {
        recognizer?.destroy()
        recognizer = null
    }

    private fun hasSpeechToPause(): Boolean = activeSpeech != null || pendingSpeech.isNotEmpty()

    private fun pauseForPossibleInterruption() {
        val active = activeSpeech
        if (active != null) {
            val remainder = active.text.drop(active.offset).trimStart()
            if (remainder.isNotEmpty()) pendingSpeech.addFirst(remainder)
            activeSpeech = null
            tts?.stop()
        }
        playbackPaused = true
    }

    private fun resumeAfterFalseInterruption() {
        interruptionCandidateConfirmed = false
        playbackPaused = false
        trace("candidate rejected; playback resumed")
        startNextSpeech()
        emit(VoiceEvent.InterruptionRejected)
    }

    private fun startNextSpeech() {
        if (playbackPaused || activeSpeech != null) return
        val text = pendingSpeech.pollFirst()
        if (text == null) {
            emit(VoiceEvent.Idle)
            return
        }
        val utterance = ActiveSpeech(text = text, utteranceId = UUID.randomUUID().toString())
        activeSpeech = utterance
        trace("tts queued chars=${text.length}")
        val result = tts?.speak(text, TextToSpeech.QUEUE_FLUSH, Bundle(), utterance.utteranceId)
        if (result != TextToSpeech.SUCCESS) {
            trace("tts rejected utterance result=$result")
            activeSpeech = null
            emit(VoiceEvent.Error("Text-to-speech couldn’t play this reply. Check the device’s text-to-speech settings."))
        }
    }

    private fun restartListeningSoon() {
        val generation = conversationGeneration
        mainHandler.postDelayed({
            if (generation == conversationGeneration) startListening()
        }, RESTART_DELAY_MS)
    }

    /** A compact two-note readiness cue synthesized on-device; no media asset. */
    private fun playStartupCue() {
        val tone = ToneGenerator(AudioManager.STREAM_MUSIC, STARTUP_CUE_VOLUME)
        tone.startTone(ToneGenerator.TONE_PROP_ACK, 70)
        mainHandler.postDelayed({ tone.startTone(ToneGenerator.TONE_PROP_BEEP2, 110) }, 82L)
        mainHandler.postDelayed(tone::release, STARTUP_CUE_DURATION_MS + 100L)
    }

    private fun recognitionIntent() = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
        .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
        .putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault().toLanguageTag())
        .putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
        // Advisory endpointing for recognizers that support it.
        .putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 650L)
        .putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 950L)

    private fun trace(message: String) {
        Log.d(LOG_TAG, "+${SystemClock.elapsedRealtime()}ms $message")
    }

    private companion object {
        const val LOG_TAG = "MissionVoice"
        const val RESTART_DELAY_MS = 180L
        const val INTERRUPTION_CONFIRMATION_MS = 180L
        const val STARTUP_CUE_DURATION_MS = 260L
        const val STARTUP_CUE_VOLUME = 24
    }

    private class ActiveSpeech(val text: String, val utteranceId: String, var offset: Int = 0)
}

sealed interface VoiceEvent {
    data object Preparing : VoiceEvent
    data object Listening : VoiceEvent
    data object InterruptionCandidate : VoiceEvent
    data object InterruptionRejected : VoiceEvent
    data object Processing : VoiceEvent
    data class PartialTranscription(val text: String) : VoiceEvent
    data class Transcribed(val rawText: String, val payload: String) : VoiceEvent
    data object Speaking : VoiceEvent
    data object Idle : VoiceEvent
    data class Error(val message: String) : VoiceEvent
}

/** Conservative final-text cleanup. The user keeps the literal transcript. */
private object VoiceTranscriptCleaner {
    private val standaloneFillers = Regex(
        "(?i)(?:^|[\\s,;:])(?:um+|uh+|er+|ah+|hmm+|mm+)(?=$|[\\s,;:.!?])",
    )

    fun clean(text: String): String = standaloneFillers.replace(text, " ")
        .replace(Regex("\\s+"), " ")
        .replace(Regex("\\s+([,;:.!?])"), "$1")
        .trim()
}
