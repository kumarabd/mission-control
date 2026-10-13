# Design system (iOS)

Operate mode, native iOS. Source of truth is code: `MissionControl/UI/`.

- **Palette:** `MissionTheme` (sage tint on warm neutrals), with light, dark and increased-contrast values. New screens read it through `Tok` (`canvas`, `surface`, `raised`, `hairline`, `text`, `muted`, `accent`, `onAccent`, `warn`, `critical`).
- **Meaning colors:** `MissionTone` (focus, scheduled, attention, reminder, completed) is the only way colour carries meaning, always paired with a symbol and a label.
- **Type:** Hanken Grotesk via `Font.mission(_:_:)` for text, IBM Plex Mono via `Font.missionMono` for small labels and numbers. Both follow Dynamic Type. No fixed point sizes.
- **Space:** 4-pt grid, `Space.xs/s/m/l/xl` = 4/8/12/16/24. Screen gutter 16.
- **Shape:** cards 16pt continuous radius, compact 12pt, hairline stroke, no shadows.
- **Navigation:** system TabView (Today, Progress, Journal, Memory, Classic), NavigationStack with large titles, sheets for capture and check-ins. Capture is a floating button, not a tab.
- **Components:** `MissionCard`, `SectionHeading`, `MissionStatusLabel`, `MissionIconBadge`, `PrimaryButtonStyle`, `SecondaryButtonStyle`, `Chip`, `EmptyState`, `MissionProgressBar`, `CaptureButton`.
- **Motion:** system transitions; `MissionPressStyle` for press feedback; everything honours Reduce Motion.
- **Voice:** plain, second person, never scolding. Controls name their action ("Plan my day", "Close the day").

## Icons and actions

SF Symbols only, one meaning per icon. **There is no plus in the app**: it meant both "log one" and "create", and meant neither clearly. Controls are drawn, not captioned: an icon-only control always has an accessibility label (VoiceOver says what the picture means), and state is carried by the shape (segments, fill, a dashed outline) so colour is never the only signal. Outline for an action, filled for a state.

| Meaning | Symbol | Where |
|---|---|---|
| I did it (record one) | the **ring is the control**: one segment per time it should be done today, `checkmark` inside; tap to fill the next segment | routine rows, Today, routine detail; tappable only on a day the routine applies |
| It is done | the ring becomes a solid accent disc with a white `checkmark` | a routine that has reached its count |
| Not today | dashed ring with `calendar`, not tappable, with "Next: Sunday" beside it | a routine that does not apply today |
| Take one back | `arrow.uturn.backward`, icon only | routine detail, deliberate, never in a list row |
| Easier version | `timer`, icon only | routine detail |
| Got it (clear a cue that fired) | `checkmark.circle` | Coming up, reminder detail |
| Write or create something | `square.and.pencil` | Progress, Memory, Journal toolbars |
| Talk to the assistant | `bubble.left.fill` (floating button), `bubble.left` (inline) | capture, goal detail |
| Voice | `mic.fill` to start, `stop.circle.fill` to end, `arrow.up` to send | capture sheet |
| Add a task to today | `checklist` | Today menu |
| A nudge | `bell`, `bell.badge` to add one, `xmark.circle.fill` to remove one | reminders, new routine |
| Repeats | `repeat` | cues, routines |
| Easier version | `timer` | routine detail |
| Snooze / close the day | `moon.zzz` / `moon.stars` | cues, Today menu |
| Delete / archive | `trash` / `archivebox` | destructive actions, always confirmed or swipeable |
| Do this next | `scope` | Today |

