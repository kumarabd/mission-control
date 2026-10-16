# Design system (iOS)

Operate mode, native iOS. Source of truth is code: `MissionControl/UI/`.

- **Palette:** `MissionTheme` (sage tint on warm neutrals), with light, dark and increased-contrast values. New screens read it through `Tok` (`canvas`, `surface`, `raised`, `hairline`, `text`, `muted`, `accent`, `onAccent`, `warn`, `critical`).
- **Meaning colors:** `MissionTone` (focus, scheduled, attention, reminder, completed) is the only way colour carries meaning, always paired with a symbol and a label.
- **Type:** Hanken Grotesk via `Font.mission(_:_:)` for text, IBM Plex Mono via `Font.missionMono` for small labels and numbers. Both follow Dynamic Type. No fixed point sizes.
- **Space:** 4-pt grid, `Space.xs/s/m/l/xl` = 4/8/12/16/24. Screen gutter 16.
- **Shape:** cards 16pt continuous radius, compact 12pt, hairline stroke, no shadows.
- **Navigation:** system TabView (Today, Goals, Chat, Memory), NavigationStack with large titles, sheets for quick forms and check-ins. Each tab's bar leads with the app mark (`AppMark`) and trails with Settings — the same control in the same place everywhere — plus that tab's own action. Settings contains Classic.
- **Components:** `MissionCard`, `SectionHeading`, `MissionStatusLabel`, `MissionIconBadge`, `PrimaryButtonStyle`, `SecondaryButtonStyle`, `Chip`, `EmptyState`, `MissionProgressBar`, `AppMark`.
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
| A reminder | `bell` (to come), `checkmark.circle` (done), with the time it will be heard | Goals ▸ Reminders, reminder detail |
| Got it (clear a cue that fired) | `checkmark.circle`, icon only | Goals ▸ Reminders, reminder detail |
| What the assistant has sent | `tray.full` with a count, `tray` when there is nothing new | Today's toolbar, opening Notifications |
| A goal's one-off step | `circle` / `checkmark.circle.fill` in an actionable tracker; `flag` / `flag.checkered` in legacy review | goal tracker / legacy goal review |
| Write or create something | `square.and.pencil` | Goals and Memory toolbars |
| Talk to the assistant | `bubble.left` | the Chat tab; inline where a screen starts the conversation |
| Voice | `mic.fill` to start, `stop.circle.fill` to end, `arrow.up` to send, `stop.fill` to stop a turn | Chat composer |
| The app itself | `scope` (decorative, never a control; the same glyph marks "do this next" in content) | the leading end of every tab's bar |
| Add a task to today | `checklist` | Today menu |
| A nudge | `bell.badge` to add one, `xmark.circle.fill` to remove one | routine detail, new routine |
| Repeats | `repeat` | cues, routines |
| Easier version | `timer` | routine detail |
| Snooze / close the day | `moon.zzz` / `moon.stars` | cues, Today menu |
| Delete / archive | `trash` / `archivebox` | destructive actions, always confirmed or swipeable |
| Do this next | `scope` | Today; approved goal trackers also finish one-off steps |


## Today

Use a native list with a compact date, **Schedule**, then **Tasks**. There is no aggregate day ring or planning/reflection ellipsis menu.

- Schedule contains calendar events and any plan item with `startAt` (including check-ins), as a compact window about four rows tall with the Now rule centred: the day scrolls inside the window, rows crossing its edges soften, and a Back to now chip appears once the person has moved away. At accessibility text sizes the window grows taller and time moves above the title rather than taking a fixed column. Reduce Motion keeps the rows still.
- A routine is untimed work, never a schedule row: its nudge times are the assistant's cue to consider prompting, not times the person is due at (Project Hub `projects/life-engine/adr/0007-nudges-belong-to-routines.md`). Nudges are shown and edited on the routine detail. A routine shows its shared daily count; the engine does not attribute a log to a particular nudge, so the UI must not imply per-instance completion.
- Reminders are not on Today. They live in Goals ▸ Reminders, shelved Due / Upcoming / No time set / Done, where a fired cue is cleared and a reminder is snoozed or deleted. A tapped reminder notification lands there.
- Tasks contains untimed plan items, routines due today and an unscheduled next goal step. A step already represented by a plan item is not duplicated. Goal context appears in linked task rows.
- Completion controls are 44pt or larger. A routine records one; a task or step completes.
- Move to bottom reorders untimed work only. A labeled Undo last action row is placed before the remaining tasks; actions without an undo operation clear the previous undo.
- Notifications is reached from Today's tray: what the assistant has sent, newest first, unread first-class. Opening one marks it read and follows its link to the record it is about.
- Calendar access is explicitly requested from Include my calendar rather than on launch.
- Loading and failed loads are distinct from an empty day; cached records remain visible after a failed refresh.

## Chat and navigation

Today, Goals, Chat and Memory are peers. Goals opens with Goals selected; Routines and Reminders remain segmented views. Classic is available in Settings without migrating its legacy task store.

Chat is one ongoing conversation with the assistant: the iOS gateway gives a person a single session, so there is no list of conversations, and the gateway replays the recent tail whenever the socket opens. Voice and text take turns owning that socket, so the two never answer the same turn. A finished turn refreshes goals, plan, reminders and routines; workspace updates are receipts from returned records, with View and Change actions. Change prefills the composer; it does not parse prose or pretend the agent supports a structured plan preview. Screens that start a conversation (a new goal, a memory to correct or discuss) open Chat with their text in the composer.

Journal and the local weekly-review screen are removed. Memory preserves browsing/search of existing local records and removes direct save/edit controls. Capture handles requests to remember or correct information. The accepted remote direction opens on Reflections with About you one tap away, powered by agent-brain semantic views; generated routine/reminder views remain a separate discussion. Goal trackers follow the accepted Life Engine catalog contract.

## Goal trackers

The agent selects approved modules and headings; the client owns the presentation. Use the existing continuous card shape, hairlines, semantic palette and scalable fonts. iPhone presents purpose, a pending proposal review and up to four modules in a stack before More; iPad uses two columns except at accessibility sizes. Charts show recorded outcomes and desired targets separately. Check-ins use labeled native forms and disclosure for recent observations; revisions show a reason and preview before acceptance. Legacy goals and unsupported presentations retain basic review. Canonical contract and decisions live in Project Hub: `projects/life-engine/specs/goal-trackers.md` and `projects/mission-control/adr/0008-agent-composed-native-goal-trackers.md`.

Memory is a read surface. Reflections/About you are semantic projections of agent-brain; the harness retains ownership of memory reasoning and updates. Today, routine and tracker actions retain their existing native controls.
