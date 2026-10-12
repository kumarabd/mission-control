# Design system (iOS)

Operate mode, native iOS. Source of truth is code: `MissionControl/UI/`.

- **Palette:** `MissionTheme` (sage tint on warm neutrals), with light, dark and increased-contrast values. New screens read it through `Tok` (`canvas`, `surface`, `raised`, `hairline`, `text`, `muted`, `accent`, `onAccent`, `warn`, `critical`).
- **Meaning colors:** `MissionTone` (focus, scheduled, attention, reminder, completed) is the only way colour carries meaning, always paired with a symbol and a label.
- **Type:** Hanken Grotesk via `Font.mission(_:_:)` for text, IBM Plex Mono via `Font.missionMono` for small labels and numbers. Both follow Dynamic Type. No fixed point sizes.
- **Space:** 4-pt grid, `Space.xs/s/m/l/xl` = 4/8/12/16/24. Screen gutter 16.
- **Shape:** cards 16pt continuous radius, compact 12pt, hairline stroke, no shadows.
- **Navigation:** system TabView (Today, Goals, Journal, Memory, Classic), NavigationStack with large titles, sheets for capture and check-ins. Capture is a floating button, not a tab.
- **Components:** `MissionCard`, `SectionHeading`, `MissionStatusLabel`, `MissionIconBadge`, `PrimaryButtonStyle`, `SecondaryButtonStyle`, `Chip`, `EmptyState`, `MissionProgressBar`, `CaptureButton`.
- **Motion:** system transitions; `MissionPressStyle` for press feedback; everything honours Reduce Motion.
- **Voice:** plain, second person, never scolding. Controls name their action ("Plan my day", "Close the day").
