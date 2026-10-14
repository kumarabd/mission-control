# Design system (iOS)

Operate mode, native iOS. Source of truth is code: `MissionControl/UI/`.

- **Palette:** `MissionTheme` (sage tint on warm neutrals), with light, dark and increased-contrast values. New screens read it through `Tok` (`canvas`, `surface`, `raised`, `hairline`, `text`, `muted`, `accent`, `onAccent`, `warn`, `critical`).
- **Meaning colors:** `MissionTone` (focus, scheduled, attention, reminder, completed) is the only way colour carries meaning, always paired with a symbol and a label.
- **Type:** Hanken Grotesk via `Font.mission(_:_:)` for text, IBM Plex Mono via `Font.missionMono` for small labels and numbers. Both follow Dynamic Type. No fixed point sizes.
- **Space:** 4-pt grid, `Space.xs/s/m/l/xl` = 4/8/12/16/24. Screen gutter 16.
- **Shape:** cards 16pt continuous radius, compact 12pt, hairline stroke, no shadows.
- **Navigation:** system TabView (Today, Goals, Memory), NavigationStack with large titles, sheets for capture and check-ins. Capture is a labeled floating action, not a tab; content reserves space for it. Settings is reachable from every tab and contains Classic.
- **Components:** `MissionCard`, `SectionHeading`, `MissionStatusLabel`, `MissionIconBadge`, `PrimaryButtonStyle`, `SecondaryButtonStyle`, `Chip`, `EmptyState`, `MissionProgressBar`, `CaptureButton`.
- **Motion:** system transitions; `MissionPressStyle` for press feedback; everything honours Reduce Motion.
- **Voice:** plain, second person, never scolding. Controls name their action ("Add a task", "Capture", "Undo last action").

## Icons and actions

SF Symbols only, one meaning per icon. **There is no plus in the app**: it meant both "log one" and "create", and meant neither clearly. Use visible labels for unfamiliar actions. An icon-only control always has an accessibility label (VoiceOver says what the picture means), and state is carried by the shape (segments, fill, a dashed outline) so colour is never the only signal. Outline for an action, filled for a state.

| Meaning | Symbol | Where |
|---|---|---|
| I did it (record one) | the **ring is the control**: one segment per time it should be done today, `checkmark` inside; tap to fill the next segment | routine rows, Today, routine detail; tappable only on a day the routine applies |
| It is done | the ring becomes a solid accent disc with a white `checkmark` | a routine that has reached its count |
| Not today | dashed ring with `calendar`, not tappable, with "Next: Sunday" beside it | a routine that does not apply today |
| Take one back | `arrow.uturn.backward`, icon only | routine detail, deliberate, never in a list row |
| Easier version | `timer`, icon only | routine detail |
| A calendar event in the day | `calendar` | Today, same row shape as everything else |
| A reminder in the day | `bell` (to come), `bell.badge.fill` (fired, waiting for you), `bell.slash` (cleared), with the time it fires | Today, in time order with tasks and events |
| Got it (clear a cue that fired) | `checkmark.circle`, icon only | Today, reminder detail |
| A goal's one-off step | `circle` / `checkmark.circle.fill` in an actionable tracker; `flag` / `flag.checkered` in legacy review | goal tracker / legacy goal review |
| Write or create something | `square.and.pencil` | Goals and Memory toolbars |
| Talk to the assistant | `bubble.left.fill` (floating button), `bubble.left` (inline) | capture, goal detail |
| Voice | `mic.fill` to start, `stop.circle.fill` to end, `arrow.up` to send | capture sheet |
| Add a task to today | `checklist` | Today menu |
| A nudge | `bell`, `bell.badge` to add one, `xmark.circle.fill` to remove one | reminders, new routine |
| Repeats | `repeat` | cues, routines |
| Easier version | `timer` | routine detail |
| Snooze / close the day | `moon.zzz` / `moon.stars` | cues, Today menu |
| Delete / archive | `trash` / `archivebox` | destructive actions, always confirmed or swipeable |
| Do this next | `scope` | Today; approved goal trackers also finish one-off steps |


## Today

Use a native list with a compact date, **Schedule**, then **Tasks**. There is no aggregate day ring or planning/reflection ellipsis menu.

- Schedule contains calendar events, any plan item with `startAt` (including check-ins), reminder occurrences and each routine nudge time. Times are chronological, with a live Now marker. At accessibility text sizes, time moves above the title rather than taking a fixed column.
- Routine nudges show the shared daily count. The engine does not attribute a log to a particular nudge, so the UI must not imply per-instance completion.
- Tasks contains untimed plan items, untimed routines, undated reminders and an unscheduled next goal step. A step already represented by a plan item is not duplicated. Goal context appears in linked task rows.
- Completion controls are 44pt or larger. A routine records one, a task/step completes, and an undated reminder completes. Timed reminders acknowledge an occurrence or snooze; merely firing a cue is not labeled user completion.
- Move to bottom reorders untimed work only. A labeled Undo last action row is placed before the remaining tasks; actions without an undo operation clear the previous undo.
- All reminders provides access to future and undated records. Calendar access is explicitly requested from Include my calendar rather than on launch.
- Loading and failed loads are distinct from an empty day; cached records remain visible after a failed refresh.

## Capture and navigation

Today, Goals and Memory are peers. Goals opens with Goals selected; Routines remains a segmented view. Classic is available in Settings without migrating its legacy task store.

Capture refreshes goals, plan, reminders and routines after typed or voice turns. Workspace updates are receipts from returned records, with View and Change actions. Change prefills a contextual assistant request; it does not parse prose or pretend the agent supports a structured plan preview.

Journal and the local weekly-review screen are removed. Memory retains local saved memories and labels the local save boundary; agent-brain integration, reflection and generated routine/reminder views remain undecided. Goal trackers follow the accepted Life Engine catalog contract.

## Goal trackers

The agent selects approved modules and headings; the client owns the presentation. Use the existing continuous card shape, hairlines, semantic palette and scalable fonts. iPhone presents purpose, a pending proposal review and up to four modules in a stack before More; iPad uses two columns except at accessibility sizes. Charts show recorded outcomes and desired targets separately. Check-ins use labeled native forms and disclosure for recent observations; revisions show a reason and preview before acceptance. Legacy goals and unsupported presentations retain basic review. Canonical contract and decisions live in Project Hub: `projects/life-engine/specs/goal-trackers.md` and `projects/mission-control/adr/0008-agent-composed-native-goal-trackers.md`.
