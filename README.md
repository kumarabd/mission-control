# Mission Control

Mission Control is a calm, native assistant for iPhone and iPad: one chat with your agent, next to the day, goals and
memory it keeps for you.

## What it is

- **Today** — the day's tasks and events, read from the Life Engine through the router.
- **Goals** — goals, their steps and the views the agent composes from them.
- **Chat** — one conversation with the assistant, by typing or talking. It behaves like a messaging app: delivery
  states, a recent window kept on the phone, and replies that arrive while you are on another tab.
- **Memory** — what the assistant remembers, read from Agent Brain.

Nothing about the workspace is decided on the phone: the assistant writes through the Life Engine, the same operations
the screens use.

## Voice

Tap the microphone in Chat to speak instead of typing. Speech is transcribed on-device with iOS 26
`SpeechTranscriber`; only text reaches the gateway. Replies stream back and are spoken sentence by sentence through the
system voice. Talking takes over the conversation until you end voice, then the thread replays so the spoken turns sit
in the chat with everything typed.

While a session runs, the chat dims behind a semi-transparent card carrying the assistant's ring/waveform mark, alive
in the matching state (getting ready, listening, thinking, speaking), with the live words and an End voice button.
CarPlay shows the same mark as its voice screen and on the assistant, Today and goal templates.

The assistant's replies are styled for how the message was said: voice turns ask the gateway for spoken prose, typed
turns for text. `MobileGateway.sendMessage` requires its `mode`, so no caller can send the wrong one by default.

Audio is not saved or transmitted by the app.

## CarPlay

Mission Control is a voice-based conversation app on CarPlay (`com.apple.developer.carplay-voice-based-conversation`).
The assistant is the root screen — the mark is the talk control — with the last exchange, the next items of today and
the open goals beneath; Today opens the full day, and an item or goal opens read-only details with Mark done and
Snooze. Template depth stays within the category's three-screen limit. Nothing starts recording until the driver taps
the mark.

## Architecture

```
MissionControl/
├── App/                 App entry point, root and tabs
├── Core/
│   ├── Auth/            Clerk sign-in and gateway token
│   ├── Domain/          Chat transcript, models, planner, view kit
│   ├── Engine/          Life Engine client and local state
│   ├── Onboarding/      Provisioning gate
│   ├── Push/            APNs registration and links
│   └── Remote/          Life, gateway, memory and model APIs (incl. MobileGateway)
├── Features/
│   ├── Capture/         Chat: model, view, bubbles — and Voice/ (speech, mark, overlay, gateway turns)
│   ├── CarPlay/         Voice-first assistant, today and details as CarPlay templates
│   ├── Goals/           Goals, kit screens
│   ├── Memory/          Memory
│   ├── Notifications/   Inbox
│   ├── Progress/        Goal progress
│   ├── Settings/        Account, agents, models, connections
│   └── Today/           Today and item sheets
└── UI/                  Theme and shared components
```

The same target supports iPhone and iPad; iPad adapts the tab bar to a sidebar and uses two-column layouts.

## Run

Open `MissionControl.xcodeproj` in Xcode 26 or later, select an iOS 26+ simulator or device, and run the
**MissionControl** scheme.

## Local checks (no simulator)

From the repository root on a Mac with Xcode installed:

```sh
xcrun swiftc -parse-as-library MissionControl/Core/Domain/ChatTranscript.swift MissionControl/Core/Domain/ChatStore.swift Tests/ChatTranscriptChecks.swift -o /private/tmp/chat-transcript-checks
/private/tmp/chat-transcript-checks

xcrun swiftc -parse-as-library MissionControl/Features/Capture/Voice/VoiceInteractionPolicy.swift MissionControl/Features/Capture/Voice/VoiceConversationText.swift Tests/VoiceInteractionChecks.swift -o /private/tmp/mission-voice-interaction-checks
/private/tmp/mission-voice-interaction-checks
```

The rest — Life contract, views, notifications, memory, gateway agents, model tiers, planner, markdown, schedule — is
documented in [Tests/README.md](Tests/README.md).

## Clerk authentication setup

The iOS target includes Clerk's `ClerkKit` package and signs in from the welcome screen.

Before signing in, configure the following outside source control:

1. In Clerk, enable the Native API, add the `com.kumarabd.MissionControl` native application, and enable Google in SSO connections.
2. Set the `CLERK_PUBLISHABLE_KEY` build setting for both Debug and Release (or provide it through an uncommitted `.xcconfig`).
3. The target declares `webcredentials:clerk.nighthawklabs.org` as an Associated Domain (the shared production Clerk instance — the same one the web chat and gateway use). Enable the Associated Domains capability for this App ID in Apple Developer, then regenerate/download any affected provisioning profile.
4. In Clerk Native Applications, allowlist `com.kumarabd.MissionControl://callback` for mobile SSO redirects.

The gateway client sends a freshly acquired Clerk session token in its required first WebSocket frame, then exchanges
text turns and streamed response deltas over `wss://harness-router.nighthawklabs.org/gateway/ios/ws`. Voice I/O stays
on-device.
