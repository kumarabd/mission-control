# Mission Control · Android

An Android-native, assistant-centered personal dashboard built with Kotlin and Jetpack Compose.

## Current scope

- Edge-to-edge home screen with current time, weather/system samples, and attention rail.
- Six personal spaces arranged around a central assistant presence.
- A centered 90%-screen detail dialog for every space.
- Sample dashboard content only. Device telemetry, camera, and task persistence are not connected yet.
- An assistant gateway transport is present, but it opens only during a person-initiated turn while the app is foregrounded. It closes on completion, cancellation, or backgrounding.
- Voice uses Android's on-device speech APIs for microphone capture and playback; only the transcription leaves the device for an active assistant turn. Internal agent progress, tool activity, and transport status can appear in the visual progress surface but are never spoken.

## Voice interruption behavior

Android speech onset immediately silences and preserves the unread reply, because an on-device recognizer can detect the user while TTS is audible but may not produce a partial transcript until playback has stopped. The app still holds a 180 ms confirmation window before surfacing the interruption. A cleaned, non-empty final transcript commits it and is sent as the next user message; an empty result or no-match resumes the retained reply. This stays entirely on-device until the final transcript is sent and works even after the gateway has finished generating. One on-device `SpeechRecognizer` is retained for the full conversation and restarted between natural STT turns, avoiding service reconnect gaps during barge-in.

For device debugging, filter Logcat on `MissionVoice`. The entries contain lifecycle state, timings, callback/error codes, and character counts only—never the transcript itself.

The Android `SpeechRecognizer` controls endpointing and may vary by device or installed recognition service. If a device's playback leaks into the microphone strongly enough to be recognized as speech, a future audio-recording pipeline with acoustic echo cancellation and VAD is needed for fully reliable hands-free barge-in.

## Architecture

```text
app/src/main/java/org/nighthawklabs/missioncontrol/
├── core/model/       # Stable domain models shared by features
├── core/assistant/   # Realtime gateway transport and authentication boundary
├── core/voice/       # Android speech recognition and text-to-speech coordination
├── feature/dashboard/# Dashboard state and composable UI
├── ui/theme/         # App-specific Material 3 palette and typography
└── MainActivity.kt   # Edge-to-edge app entry point
```

The UI uses Material 3 components and Compose state. Feature data is deliberately isolated from the UI components so a future backend and Room cache can be added without reworking the dashboard layout.

## Assistant connection policy

The Android transport uses the same mobile gateway frames as iOS: it authenticates with a Clerk session token, identifies this installation with a locally stored device ID, and persists the latest completed turn cursor. Historical replay establishes that cursor but is never rendered or spoken as a new answer. The dashboard itself never holds a realtime socket open. Both conditions must be true before it connects:

1. The app is foregrounded.
2. The person has explicitly started an assistant interaction.

The central orb opens a native Mission Control account sheet only when a token is needed. Its Google action uses Clerk OAuth and Android's secure system authentication session; the dashboard itself never hands over to Clerk's full hosted portal. Once authenticated, the gateway retrieves a fresh session token immediately before opening a turn. The publishable key is a build setting; no token or secret key is embedded in the app.

## Run

Open this directory in Android Studio, choose an emulator or Android device, then run the `app` configuration. The project targets Android API 36 and supports API 24+.
