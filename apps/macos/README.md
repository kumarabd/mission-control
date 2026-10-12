# Mission Control for macOS

Native SwiftUI client for the Mission Control assistant gateway. It intentionally
uses the `macos` gateway scope, so desktop conversations are separate from the
browser and mobile histories while retaining the browser's selectable-session UX.

## Run

1. Open `MissionControlMac.xcodeproj` in Xcode.
2. Select the `MissionControlMac` scheme and **My Mac**.
3. Run the app and sign in with the same Clerk account used by the other clients.

The checked-in defaults point to the current Mission Control Clerk instance and
shared router. The client sends its Gateway traffic through the router's
`/gateway` prefix. Override them for another environment with the
`CLERK_PUBLISHABLE_KEY` and `ROUTER_BASE_URL` scheme environment variables.

The gateway deployment must include the native endpoints added alongside this
client: `/macos/ws`, `/macos/sessions`, `/macos/send`, `/macos/poll`,
`/macos/respond`, and `/macos/cancel`.

## Rich responses

Assistant messages use Microsoft's `SwiftStreamingMarkdown` renderer for
incremental Markdown, code blocks, tables, links, and other structured content.
Tool activity, progress, approvals, message actions, and session management stay
native to this app because they map directly to Mission Control gateway frames.

The package is pinned to a reviewed commit because its current tagged releases
contain revision-based transitive dependencies that Swift Package Manager does
not allow behind a normal semantic-version requirement. On the first Xcode
build, approve the standard trust prompt for the package's `EquatableMacros`
macro. Command-line builds can use `-skipMacroValidation` after the dependency
has been reviewed; the project does not disable macro validation permanently.
