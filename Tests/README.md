# Native iOS local checks

Run from the repository root on a Mac with Xcode installed. These checks do not launch the app or a simulator. The embedded plist lets SwiftData identify the standalone executable.

## Voice state and conversation text

These Foundation-only checks do not require microphone permission:

    xcrun swiftc -parse-as-library MissionControl/Legacy/Services/VoiceInteractionPolicy.swift MissionControl/Legacy/Services/VoiceConversationText.swift Tests/VoiceInteractionChecks.swift -o /private/tmp/mission-voice-interaction-checks
    /private/tmp/mission-voice-interaction-checks

Covers noise-only and one-spike rejection, sustained recognized speech, stale
activity, silence endpointing, speaker-text rejection, stop/restart generations,
state priority, and separate user/assistant text surviving STT restarts and false
barge-in. These checks do not prove acoustic echo cancellation, native speech
callback ordering, device latency, or gateway behavior. See the canonical iOS
implementation document in Project Hub for the physical-device test checklist.

## Day grouping

```sh
xcrun swiftc -parse-as-library MissionControl/Legacy/Models/MissionTask.swift MissionControl/Legacy/Services/DayTaskSchedule.swift Tests/DayTaskScheduleChecks.swift -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker Tests/FocusChecks-Info.plist -o /private/tmp/mission-day-schedule-checks
/private/tmp/mission-day-schedule-checks
```

Covers chronological order, equal times, the current minute, completed and unscheduled tasks, removing a time, day rollover, both daylight-saving boundaries, and 100 uncapped flexible tasks.

## Existing task store upgrade

The original and updated model are compiled separately with the same module name. Each verification opens the same temporary store in a fresh process. This checks a real lightweight schema migration, retention of task fields, saving a time, and removing it. It does not access the app's store.

```sh
xcrun swiftc -parse-as-library -module-name MissionTimingMigration -D LEGACY_TASK_SCHEMA Tests/Fixtures/MissionTaskBeforeTiming.swift Tests/TaskTimingPersistenceChecks.swift -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker Tests/FocusChecks-Info.plist -o /private/tmp/mission-timing-legacy-checks
xcrun swiftc -parse-as-library -module-name MissionTimingMigration MissionControl/Legacy/Models/MissionTask.swift Tests/TaskTimingPersistenceChecks.swift -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker Tests/FocusChecks-Info.plist -o /private/tmp/mission-timing-current-checks
timing_check_dir=$(mktemp -d /private/tmp/mission-timing-migration.XXXXXX)
/private/tmp/mission-timing-legacy-checks "$timing_check_dir" create
/private/tmp/mission-timing-current-checks "$timing_check_dir" migrate
/private/tmp/mission-timing-current-checks "$timing_check_dir" verify
/private/tmp/mission-timing-current-checks "$timing_check_dir" verify-removed
```

Keep `Fixtures/MissionTaskBeforeTiming.swift` outside the app target; it is the original schema fixture, not a second application model.

## Available-height allocation

```sh
xcrun swiftc -parse-as-library MissionControl/Legacy/Features/Dashboard/DashboardHeightLayout.swift Tests/DashboardHeightChecks.swift -o /private/tmp/mission-dashboard-height-checks
/private/tmp/mission-dashboard-height-checks
```

Covers sparse, dense, exact-fit, overflowing, and large-content allocations. On-device appearance, Dynamic Type, and interaction checks still need to be performed in the app.

## Planner rules (capture classification, "I have N minutes", replan, close the day, weekly review)

```sh
xcrun swiftc -parse-as-library MissionControl/Core/Domain/Models.swift MissionControl/Core/Domain/Planner.swift Tests/PlannerChecks.swift -o /private/tmp/mission-planner-checks
/private/tmp/mission-planner-checks
```

## Provisioning gate classification

`Tests/ProvisioningChecks.swift` checks `Provisioning.isMissing`; compile it with the `Provisioning` enum from `MissionControl/Core/Onboarding/ProvisionGate.swift` (a `Config.routerBaseURL` stub is needed).

## Push helpers (device-token hex, notification link to app section)

```sh
xcrun swiftc -parse-as-library MissionControl/Core/Push/PushLink.swift Tests/PushLinkChecks.swift -o /private/tmp/mission-push-link-checks
/private/tmp/mission-push-link-checks
```

## Life Engine contract (real recorded responses, request shapes, error classification)

```sh
xcrun swiftc -parse-as-library MissionControl/Core/Remote/LifeWire.swift MissionControl/Core/Remote/TrackerWire.swift MissionControl/Core/Remote/LifeAPI.swift MissionControl/Core/Remote/ItemsService.swift MissionControl/Core/Remote/GoalsService.swift MissionControl/Core/Remote/SettingsService.swift Tests/LifeContractChecks.swift -o /private/tmp/mission-life-contract-checks
/private/tmp/mission-life-contract-checks Tests/Fixtures/life
```

`Tests/Fixtures/life` is copied from the `life-engine` repository's `fixtures/`; regenerate there when the contract changes. Covers goals, tasks, calendar events and
the day (decoding, and the exact requests the services send), and how failures are classified.

Markdown blocks:

    xcrun swiftc -parse-as-library MissionControl/Core/Domain/Markdown.swift Tests/MarkdownChecks.swift -o /private/tmp/markdown-checks && /private/tmp/markdown-checks

## Schedule window

The schedule window (where the Now rule falls, how tall the window is):

    xcrun swiftc -parse-as-library MissionControl/Core/Domain/ScheduleWindow.swift Tests/ScheduleWindowChecks.swift -o /private/tmp/schedule-window-checks
    /private/tmp/schedule-window-checks

Covers chronological ordering with ties broken by id, the Now rule's place among
past and future rows (including an empty day and an item due exactly now), the
window's height at both text sizes (never taller than the rows that exist, never a
hole), and when "back to now" should appear. It does not prove scrolling, animation
or Reduce Motion — those are checked in the app.

The chat transcript (replay and streaming, made idempotent):

    xcrun swiftc -parse-as-library MissionControl/Core/Domain/ChatTranscript.swift MissionControl/Core/Domain/ChatStore.swift Tests/ChatTranscriptChecks.swift -o /private/tmp/chat-transcript-checks
    /private/tmp/chat-transcript-checks

Also covers delivery states (sending, failed, sent again, a late echo), the recent window kept on disk and restored
without a replay reordering it, and the rows the thread is drawn from (day headings, runs, times). Covers a sent message being replaced by its own echo rather than doubled, streamed
deltas appending and resetting, progress narration staying out of the answer, the
durable message superseding the stream, a replayed delta for a finished turn being
ignored, a stopped turn keeping what was already seen, an empty frame leaving no
bubble, and a whole connect replayed twice changing nothing. It does not prove what
the gateway replays (that is the mobile WebSocket contract) or how the thread looks.

    xcrun swiftc -parse-as-library MissionControl/Core/Domain/Models.swift MissionControl/Core/Domain/Planner.swift MissionControl/Core/Domain/WorkspaceUpdate.swift MissionControl/Core/Engine/LifeEngine.swift MissionControl/Core/Engine/Life.swift MissionControl/Core/Remote/LifeWire.swift MissionControl/Core/Remote/TrackerWire.swift MissionControl/Core/Remote/LifeAPI.swift MissionControl/Core/Remote/ItemsService.swift MissionControl/Core/Remote/GoalsService.swift MissionControl/Core/Remote/SettingsService.swift Tests/WorkspaceRefreshChecks.swift -o /private/tmp/workspace-refresh-checks
    /private/tmp/workspace-refresh-checks Tests/Fixtures/life

Uses recorded service responses to verify the day, tasks, events and goals refresh, completing and adding re-read them,
edited goals produce receipt data, load failures preserve previous records,
failed memory writes report failure, and retained journal history is not surfaced.
Notification delivery is stubbed; these checks do not contact a live workspace.

## Gateway notification inbox

    xcrun swiftc -parse-as-library MissionControl/Core/Remote/LifeWire.swift MissionControl/Core/Remote/TrackerWire.swift MissionControl/Core/Remote/NotificationsAPI.swift MissionControl/Features/Notifications/NotificationsModel.swift Tests/NotificationsChecks.swift -o /private/tmp/mission-notifications-checks
    /private/tmp/mission-notifications-checks

Covers the inbox envelope (items, unread, next_before), microseconds surviving the
decode, a malformed row link opening nothing while the rest of the page still loads,
the `before` cursor going back byte for byte, an empty 204 from marking one read,
`{"marked": n}` from marking all, the gateway's plain-text error body classifying as
`.server` rather than Life's JSON envelope, a missing token failing before any
network call, pagination appending without duplicates, a failed refresh keeping what
is already shown, and an unattached inbox reading as unavailable rather than broken.
It does not contact a live gateway.

## Views (goal, task or event trackers)

    xcrun swiftc -parse-as-library MissionControl/Core/Remote/LifeWire.swift MissionControl/Core/Remote/TrackerWire.swift MissionControl/Core/Remote/LifeAPI.swift MissionControl/Core/Remote/GoalsService.swift Tests/TrackerContractChecks.swift -o /private/tmp/mission-tracker-checks
    /private/tmp/mission-tracker-checks Tests/Fixtures/life

The view kit's calculations (the figures of a spending limit, a weigh-in and a habit, and that the engine's example manifests decode here):

    xcrun swiftc -parse-as-library MissionControl/Core/Domain/ViewKit.swift MissionControl/Core/Remote/LifeWire.swift MissionControl/Core/Remote/TrackerWire.swift MissionControl/Core/Remote/LifeAPI.swift MissionControl/Core/Remote/GoalsService.swift Tests/ViewKitChecks.swift -o /private/tmp/mission-viewkit-checks
    /private/tmp/mission-viewkit-checks Tests/Fixtures/views

Decodes engine-recorded views and observations; rejects wrong-client or unknown-module rendering; checks numeric locale handling and exact measurements_* and views_state requests. The engine integration suite covers actual idempotency, stale revisions, unit/history preservation and concurrent approval. These checks do not prove an agent turn, a live tenant rollout, or device appearance.

## Semantic Memory

`MemoryChecks.swift` exercises recorded AgentBrain responses, request auth/query encoding, source loading, unavailable services, cache preservation, pagination after a failed refresh, cancelled loads and request ordering when switching views.

```sh
xcrun swiftc -parse-as-library MissionControl/Core/Remote/LifeWire.swift MissionControl/Core/Remote/TrackerWire.swift MissionControl/Core/Remote/MemoryService.swift MissionControl/Features/Memory/MemoryModel.swift tests/MemoryChecks.swift -o /private/tmp/memory-checks
/private/tmp/memory-checks tests/Fixtures/memory
```

Fixtures are generated by AgentBrain's real Postgres `TestSemanticViewsAreBankScopedAndReadOnly` with `SEMANTIC_FIXTURES_DIR` set. They contain only synthetic test records, never live personal memory.

## Gateway agent registry (list/create/update, auth, error classification)

```sh
xcrun swiftc -parse-as-library MissionControl/Core/Remote/LifeWire.swift MissionControl/Core/Remote/TrackerWire.swift MissionControl/Core/Remote/GatewayAgentsAPI.swift Tests/GatewayAgentsChecks.swift -o /private/tmp/mission-gateway-agents-checks
/private/tmp/mission-gateway-agents-checks
```

Covers the `agent_id`/`avatar_url` request/response coding (explicit `CodingKeys`, not `Wire`'s
`.convertFromSnakeCase` — that strategy transforms the JSON document's own keys before any lookup, so it never
matches an idiomatic `agentID`/`avatarURL` property name), a plain-text `http.Error` body classifying as
`.server` rather than Life's JSON error envelope, and a missing token failing fast with `.unauthorized` before
any network call. Does not contact a live gateway.

## Model tiers (list, apply, redeploy progress, auth, error classification)

```sh
xcrun swiftc -parse-as-library MissionControl/Core/Remote/ModelsAPI.swift Tests/ModelsChecks.swift -o /private/tmp/mission-models-checks
/private/tmp/mission-models-checks
```

Covers the `llm_tiers` envelope of camelCase tier objects (`baseURL`, `hasKey`, `custom`) read with a plain
`JSONDecoder()` rather than `Wire`'s `.convertFromSnakeCase`, a deployment older than the platform/own split
omitting `mode` and `custom` and still decoding (as `"custom"` and true), both PUT bodies (`{"llm_tiers": …}`
and the `{"mode": "platform"}` revert) with the run id they answer with, the router's plain-string
`{"error": "…"}` classifying as `.server` (a 409 conflict reads as its own sentence, a 400 as its validation
message), `/llm/update`'s 404 reading as "nothing has run" rather than a failure, the run-id and latest-run
query paths, and a missing token failing fast with `.unauthorized` before any network call. Does not contact a
live router, so the Temporal redeploy the PUT starts is not exercised here.
