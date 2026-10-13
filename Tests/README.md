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
xcrun swiftc -parse-as-library MissionControl/Core/Remote/LifeWire.swift MissionControl/Core/Remote/LifeAPI.swift MissionControl/Core/Remote/RemindersService.swift MissionControl/Core/Remote/RoutinesService.swift Tests/LifeContractChecks.swift -o /private/tmp/mission-life-contract-checks
/private/tmp/mission-life-contract-checks Tests/Fixtures/life
```

`Tests/Fixtures/life` is copied from the `life-engine` repository's `fixtures/`; regenerate there when the contract changes.

Reminder state (when a reminder shows as done, and for how long):

    xcrun swiftc -parse-as-library MissionControl/Core/Remote/LifeWire.swift Tests/ReminderStateChecks.swift -o /private/tmp/reminder-state-checks && /private/tmp/reminder-state-checks
