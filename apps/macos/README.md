# Mission Control for macOS

Native SwiftUI client for the Mission Control assistant gateway. It is the
desktop-detail tier: the same workspace as the web, iPhone and iPad clients,
with more information on screen at once. It intentionally uses the `macos`
gateway scope, so desktop conversations are separate from the browser and mobile
histories while retaining the browser's selectable-session UX.

## Surfaces

- **Today** — the timed schedule beside untimed work, overdue items, priorities,
  completion, local calendar events, and the full task/event editor.
- **Goals / Tasks / Events** — the goal list and the agent-composed goal tracker
  (view kit, measurements, check-ins), linked tasks and events, and archive.
- **Chat** — conversations and forks, streamed Markdown, tool activity, skill
  task progress, approvals, cancel, agent selection, and draft handoff from
  other screens.
- **Memory** — the world diagram and list, entity relations and attributes,
  related memory and sources. About you is marked coming soon; the Reflections
  feed is removed.
- **Notifications** — the gateway inbox, unread state, mark all read, links back
  to the record they are about, and a 60-second refresh.
- **Settings** — account, agents (create/edit/disable/use), models (tiers and
  redeploy), connections (connect/authorize/disconnect), appearance, and about.

Finance, Travel and the web-only ops pages under Advanced remain web surfaces.
Live voice remains iOS/web; the Mac app has a Touch ID/password lock but not
spoken chat.

## Shared code

`Sources/MissionControl/Shared/` contains relative symlinks into the iOS
client's `MissionControl/Core`, `Features` and `UI`. The Life Engine contracts,
memory and notification clients, view-kit evaluator, world layout, goal tracker,
notifications list, settings forms and semantic design tokens therefore have one
implementation for both Apple clients. macOS-only screens live beside them.

Both clients build in Swift 5 language mode for now: the shared Core predates
strict concurrency, and `Package.swift` pins the same mode so the two targets
cannot drift on it.

## Run

1. Open `MissionControl.xcodeproj` in Xcode.
2. Select the `MissionControl` scheme and **My Mac**.
3. Run the app and sign in with the same Clerk account used by the other clients.

The checked-in defaults point to the current Mission Control Clerk instance and
shared router. The client sends its Gateway traffic through the router's
`/gateway` prefix. Override them for another environment with the
`CLERK_PUBLISHABLE_KEY` and `ROUTER_BASE_URL` scheme environment variables.

The gateway deployment must include the native endpoints added alongside this
client: `/macos/ws`, `/macos/sessions`, `/macos/send`, `/macos/poll`,
`/macos/respond`, and `/macos/cancel`. Goals, tasks, events, memory and
notifications use the same router and gateway services as the web and iOS
clients, not macOS-specific copies.

### Clerk authentication

The macOS target has its own bundle ID, `com.kumarabd.MissionControlMac`, but
the Clerk instance currently authorizes the iOS native redirect only. Until a
macOS native application is registered, the app explicitly uses
`com.kumarabd.MissionControl://callback`; override with `CLERK_REDIRECT_URL`
(or the `ClerkRedirectURL` Info.plist key). To move to the Mac redirect:

1. In Clerk, open **Native applications** and add
   `com.kumarabd.MissionControlMac`.
2. Allowlist `com.kumarabd.MissionControlMac://callback`.
3. Set `CLERK_REDIRECT_URL=com.kumarabd.MissionControlMac://callback` for the Mac
   build, or update `AppConfiguration.defaultClerkRedirectURL`.

The Mac target reads the router from `AppConfiguration` (`ROUTER_BASE_URL`, then
the checked-in default) because Xcode's generated Info.plist does not emit the
custom `RouterBaseURL` key. Shared `Config` uses that same value.

## Checks

```sh
cd apps/macos
swift build
swift test

xcodebuild -project MissionControl.xcodeproj -scheme MissionControl \
  -destination 'platform=macOS' -skipMacroValidation build CODE_SIGNING_ALLOWED=NO
```

The package is pinned to a reviewed `SwiftStreamingMarkdown` commit because its
current tagged releases contain revision-based transitive dependencies that
Swift Package Manager does not allow behind a normal semantic-version
requirement. On the first Xcode build, approve the standard trust prompt for the
package's `EquatableMacros` macro. Command-line builds can use
`-skipMacroValidation` after the dependency has been reviewed; the project does
not disable macro validation permanently.
