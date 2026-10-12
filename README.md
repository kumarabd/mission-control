# Mission Control

Mission Control is a calm, native iOS dashboard for the work that matters today.

## V1 scope

- A live current time and date header.
- Local, SwiftData-backed tasks: add and complete tasks.
- Project cards backed by mock GitHub repository data, showing repository name, description, and activity derived from `pushed_at`.

## Architecture

The app intentionally uses a lightweight, feature-oriented layout:

```
MissionControl/
├── App/                 App entry point and SwiftData container
├── Models/              MissionTask and GitHubRepository
├── Features/
│   ├── Dashboard/       Screen composition and clock
│   ├── Tasks/           Task list, row, and task creation
│   └── Projects/        Repository cards
└── Services/            Repository data provider (mock in V1)
```

`MockGitHubService` is the seam for a future authenticated GitHub API client. Tasks are persisted locally via SwiftData; repository data remains read-only in this version.

## Run

Open `MissionControl.xcodeproj` in Xcode 26 or later, select an iOS 26+ simulator or device, and run the **MissionControl** scheme.

## iPhone and iPad

The same target supports both devices. Home centers a large assistant presence beneath a horizontal time/date and sample-weather strip. Six labeled icons spread around it: Tasks, Projects, Garage, Devices, Pantry, and Wardrobe. iPad uses a wide constellation; iPhone uses a compact edge constellation with the same center, message area, and control order. The larger message area sits directly below the assistant between the lower icons, and grows into scrolling content for longer messages. Larger accessibility text uses a two-column grid. Phone details use native push navigation; iPad details open in large sheets.

Tap **Tasks** to open the full adaptive day timeline, or **Devices** to inspect the sample device information. The quiet update at the bottom uses your next timed task, earlier unfinished work, or current focus; tapping it opens Tasks. Only real task timings drive the Tasks attention badge. The top ellipsis menu contains Add Task and appearance controls.

Tap the assistant to speak to the remote assistant: tap again to finish, and the app transcribes your words on-device with iOS 26 SpeechTranscriber before sending text to the authenticated gateway. The required Apple language model installs on first use and then runs locally. Response text streams back and is spoken sentence-by-sentence through the system voice while it is still being generated. The live response and state appear below the assistant. Tapping while the assistant is responding stops local playback and begins a new spoken request; the gateway treats that message as an interrupt. iOS asks only for microphone access. Audio is not saved or transmitted by the app.

The camera and paperclip controls attached to the assistant support live VisionKit text/QR scanning, camera-photo OCR, and image/PDF imports or drops. Recognition runs on-device and the extracted payload appears under the assistant as a temporary stand-in for the future backend. Attachments are not persisted or transmitted by this V1.

Choose Graphite, Pearl, or Follow system from the dashboard settings. Reduce Motion is respected; assistant animation pauses when a space opens or the app enters the background.

On iPhone, selecting a task makes it the current focus. That selection persists on the device and falls back to the next open task when completed or deleted. Completing from Today supports Undo. Existing tasks are retained when the optional task timing field is added; signing settings are unchanged.

Weather, attention reminders, system readings, and repositories are explicitly sample data. Calendar and personal services are not connected. Tasks remain local to each device; no server synchronization or offline command queue is implemented yet.

### My day timeline

The shared My day timeline uses sage for focus, blue for scheduled information, amber for action, terracotta for reminders, and grey for completed tasks. Icons and short labels accompany colour throughout the app, including space lists and details; the palette adapts to light/dark and increased contrast. A visual-language key is available in Settings.

Tasks with an explicit time appear chronologically under **At a time**, around a live **Now** marker. Earlier unfinished tasks remain visible with their time (and date for previous days). Items beyond today are available through the calendar button. Focus highlights a task within its timing group.

Untimed tasks and day-level attention examples appear under **For today**, with icons and no connecting clock line. Untimed tasks carry forward until completed and have no deadline. Example reminders are marked Sample. Completed tasks collapse into a disclosure; they are not claimed to have been completed today because completion dates are not stored. Sparse items share the available height; crowded days retain readable text and scroll.

To schedule a task, turn on **Specific time** when adding it. Use the task's ellipsis menu on the dashboard, or its long-press menu in the task list, to set, change, or remove that time. Times are stored locally; they do not trigger notifications. Calendar integration is not connected.

### Local checks (no simulator)

From the repository root on a Mac with Xcode installed:

```sh
xcrun swiftc -parse-as-library MissionControl/Legacy/Models/MissionTask.swift MissionControl/Legacy/Services/TaskFocusSelection.swift Tests/TaskFocusSelectionChecks.swift -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker Tests/FocusChecks-Info.plist -o /tmp/mission-focus-checks
/tmp/mission-focus-checks
```

Checks cover empty/stale selections, completion, undo, deletion, and persisted identity after reopening the local store.

Timing and schema-upgrade checks are documented in [Tests/README.md](Tests/README.md).
## Clerk authentication setup

The iOS target includes Clerk's `ClerkKit` package and exposes **Continue with Google** in Dashboard → Account.

Before signing in, configure the following outside source control:

1. In Clerk, enable the Native API, add the `com.kumarabd.MissionControl` native application, and enable Google in SSO connections.
2. Set the `CLERK_PUBLISHABLE_KEY` build setting for both Debug and Release (or provide it through an uncommitted `.xcconfig`).
3. The target already declares `webcredentials:primary-jay-21.clerk.accounts.dev` as an Associated Domain. Enable the Associated Domains capability for this App ID in Apple Developer, then regenerate/download any affected provisioning profile.
4. In Clerk Native Applications, allowlist `com.kumarabd.MissionControl://callback` for mobile SSO redirects.

The persistent gateway client sends a freshly acquired Clerk session token in its required first WebSocket frame, then exchanges text turns and streamed response deltas with `wss://abishekk-gateway.nighthawklabs.org/ws`. It keeps voice I/O on-device, reconnects with a completed-turn cursor, and never speaks replayed history.
