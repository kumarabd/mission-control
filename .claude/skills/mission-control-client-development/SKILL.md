---
name: mission-control-client-development
description: Mission Control monorepo rules for setting up, debugging, changing and scaffolding the web, iOS, macOS and Android clients. Use when adding or changing a client surface, shared tokens/fonts/contracts, router or Clerk configuration, CI, or release/deployment wiring.
---

# Mission Control client development

One product, several clients. The web and macOS are the verbose consoles; iPad is focused; iPhone is crisp;
CarPlay/watch are very focused; Android is being brought to parity. Every client reads the same router, Life,
memory, notifications and gateway services. Density changes per client; records, states and actions do not.

## Non-negotiables

- **Native UI stays native.** Do not share view code across React, SwiftUI and Compose. Share design tokens, fonts,
  API contracts and fixtures instead.
- **One design system.** New colours, type or spacing come from `design/tokens.json` and `design/fonts/`. Raw hex values
  in a screen or a second font copy are defects.
- **One router.** Production is `https://api.nighthawklabs.org`; mobile gateways are
  `wss://api.nighthawklabs.org/gateway/ios/ws` and `wss://api.nighthawklabs.org/gateway/android/ws`.
- **No secrets.** `.env`, `local.properties`, `CLERK_SECRET_KEY` and tokens never enter git. Clerk publishable keys
  are public by design but environment-specific.
- **The generated token files are read-only.** Edit `design/tokens.json`, then `make tokens`.
- **No image publishing from this repo.** Container images are built and pushed by the deployment pipeline. This
  repository publishes the standalone Helm chart only.
- **Preserve unrelated work.** Check `git status` before touching a tree; this repo often carries in-flight client work.

## Repository map

| Path | Client / role |
|------|---------------|
| `apps/web/` | React 19, Vite, TypeScript, Tailwind 4, React Router. Clerk + router. Public docs in `apps/web/docs/`. |
| `apps/ios/` | iOS, iPadOS, CarPlay, watch. `MissionControl.xcodeproj`; Swift 5 language mode. |
| `apps/macos/` | macOS SwiftUI console + Swift package. Shares the iOS Core/Features through symlinks under `Sources/MissionControl/Shared/`. |
| `apps/android/` | Kotlin, Compose, Car App. JDK 21; parity work is pending. |
| `design/` | `tokens.json`, canonical fonts, app-icon sources. |
| `docs/` | `architecture.md`, `parity.md`, migration notes. |
| `scripts/` | `tokens.mjs`, `sync-fonts.sh`. |
| `.github/workflows/` | Web, Android, Foundations, standalone web chart. |

The production web deployment is **not** a chart in this repo. It is `agentWeb` in
`~/Documents/agent-harness/deploy/helm/agent-harness-shared`; that chart has no web dependency and is applied from
source. `apps/web/charts/agent-web` is a standalone distributable chart.

## Setup

Prerequisites: Node 22 (`.nvmrc`), npm 10.9.8+, Xcode 26, JDK 21 for Android (Android Studio's bundled JBR), Docker
for container checks.

```sh
nvm use
npm ci
npm run dev                 # web, http://localhost:5173
make help                   # all common checks
```

| Task | Command |
|------|---------|
| Web checks | `make web-check` (lint, typecheck, 110 tests, build) |
| macOS package | `cd apps/macos && swift build && swift test` (15 tests) |
| iOS build | `make ios-build` |
| macOS app build | `make macos-build` |
| Android | `make android-check` |
| Tokens/fonts drift | `make foundations` |

Android locally uses the bundled JDK:

```sh
cd apps/android
JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
  ./gradlew :app:testDebugUnitTest :app:assembleDebug
```

Apple command-line builds skip macro validation after the dependency has been reviewed:

```sh
xcodebuild -project apps/ios/MissionControl.xcodeproj -scheme MissionControl \
  -destination 'generic/platform=iOS Simulator' -skipMacroValidation build CODE_SIGNING_ALLOWED=NO
```

## Router and authentication

Production router: `https://api.nighthawklabs.org`. The router verifies the Clerk session and proxies `/life`,
`/brain`, `/gateway`, `/finance`, `/maps` and the onboarding routes.

| Client | Where the router lives |
|--------|------------------------|
| Web | Runtime `ROUTER_PUBLIC_URL` (deployment) or `VITE_ROUTER_BASE_URL`; dev proxy via `VITE_DEV_ROUTER_PROXY`. No hardcoded production host. |
| iOS | `apps/ios/MissionControl-Info.plist` (`RouterBaseURL`) and `MobileGateway.swift` (`.../gateway/ios/ws`). |
| macOS | `AppConfiguration.defaultRouterBaseURL` and `INFOPLIST_KEY_RouterBaseURL` in the Xcode project (Debug + Release). |
| Android | `AssistantGateway.DEFAULT_ENDPOINT` (`wss://api.nighthawklabs.org/gateway/android/ws`). |

When the router changes, update all of the above and `grep -rIn "harness-router\|abishekk-gateway" .`; a change in one
client only is a bug. Clerk redirects: iOS `com.kumarabd.MissionControl://callback`; macOS bundle
`com.kumarabd.MissionControlMac`; Android application id `org.nighthawklabs.missioncontrol`. Clerk publishable keys are
safe to ship; never add a secret key.

## Shared foundations

**Tokens** — edit `design/tokens.json`, then `make tokens`. Generated consumers:
`apps/web/src/tokens.generated.css`, the marked block in `apps/ios/MissionControl/UI/MissionTheme.swift`, and
`apps/android/.../ui/theme/DesignTokens.kt`. Run `make foundations` before handing off; CI fails on drift.
Platform-only roles (muted tints, shadows, scrims) stay hand-authored in the client.

**Fonts** — canonical files and OFL licenses live in `design/fonts/`. `make fonts` copies them to both Apple bundles
and Android `res/font`; `make foundations` checks hashes. The web uses the equivalent `@fontsource` packages.

**Contracts** — wire shapes are hand-written per platform today. A change to a router/Life/gateway/memory field must
land in `apps/web/src/lib/`, `apps/ios/MissionControl/Core/Remote/`, and the Android core in the same change, with the
same optionality and idempotency keys. Shared JSON fixtures are the parity tool until a machine-readable schema exists.

## Scaffold playbooks

### Web screen or surface

1. Put the screen in `apps/web/src/pages/` (route-level) or a domain folder; reuse `components/mission/Screen`,
   `PageHeader`, `ListCard`, `EmptyState`, `InlineError`, `Skeleton` and `components/ui` primitives.
2. Use Tailwind `flat-*` tokens backed by `themes.css`; never introduce raw hex or a new palette.
3. Read data through the existing TanStack Query client and key factories in `src/lib/`; use the Clerk token path.
4. Wire the route in `App.tsx`/`AuthenticatedApp.tsx` and the sidebar entry in `src/lib/navigation`.
5. Show loading, empty, error-with-retry and the same actions as the other clients.
6. Add a `*.test.ts(x)` beside the logic; for public docs add markdown to `apps/web/docs/` with `title` frontmatter
   (the loader publishes only files with a title).
7. Verify with `npm run lint`, `npm run typecheck`, `npm test`, `npm run build`, then the dev server and Playwright.

### Apple surface (iOS + macOS)

- **Shared feature:** create the Swift file under `apps/ios/MissionControl/Features/...` and use `Tok`/`MissionTheme`.
  The iOS Xcode project uses a synchronized folder, so it is picked up automatically.
- **Expose it to macOS:** add an individual relative symlink in the matching
  `apps/macos/Sources/MissionControl/Shared/Feature/` directory and verify it resolves. Example:
  ```sh
  ln -s ../../../../../../apps/ios/MissionControl/Features/Area/File.swift \
    apps/macos/Sources/MissionControl/Shared/Features/File.swift
  test -e apps/macos/Sources/MissionControl/Shared/Features/File.swift
  ```
- **macOS-only surface:** put it in `apps/macos/Sources/MissionControl/`; use `ConsolePageHeader`, `ConsoleStat`,
  `ConsolePanel`, `ConsoleNotice`, skeletons and hover rows. Keep toolbar/sidebar actions native and keyboard-visible.
- **iOS-only:** NavigationStack/tab or sidebar-adaptable structure; Dynamic Type, VoiceOver labels, Reduce Motion.
- Use the shared `Life`, `MemoryModel`, `NotificationsModel` and `ChatModel`; do not create client-local duplicates of
  workspace state.
- Verify: `swift build && swift test` for the package, the macOS Xcode build, and the iOS simulator build.

### Android feature

1. Follow the package split: `core/model`, `core/assistant`, `core/voice`, `feature/<area>`, `ui/theme`.
2. Read `MissionControlTheme`/`DesignTokens`; never hardcode colours or fonts.
3. Keep data access behind a model/transport boundary; the gateway turns are user-initiated and foreground-only.
4. Add unit tests beside the logic; verify with `./gradlew :app:testDebugUnitTest :app:assembleDebug`.
5. Android parity is pending; match the same service contracts and screen states even when the layout is simpler.

### New shared token or font

1. Edit `design/tokens.json` (all four variants) or add the licensed font plus OFL file under `design/fonts/`.
2. `make tokens` or `make fonts`; do not edit generated outputs.
3. `make foundations`; include the generated files in the change.
4. Build the web, Apple and Android clients; a token change is not done until all three render it.

### New API field or contract

- Update the web wire type/parser, the Swift `Core/Remote` model and the Android model in one change.
- Preserve optionality; old clients must keep working. Keep idempotency keys and occurrence semantics.
- Add a test or fixture on each platform; exercise loading, error and empty states.

### New client

Create `apps/<client>`; document it in `docs/architecture.md` and `docs/parity.md`; add it to `README.md`; use the
shared tokens/fonts and router; implement Clerk sign-in; add a path-scoped CI workflow and a README; keep the tier and
parity matrix honest. Do not fork the API contract.

## Debugging

### Web

- `npm run dev` from the repo root runs Vite with **cwd `apps/web`**. `loadEnv` and the `/docs/**/*.md` glob are
  relative to that Vite root; running Vite from the repo root will miss both.
- To pass Vite flags, run the workspace directly: `npm run dev -w @mission-control/web -- --host=127.0.0.1` (the root
  `npm run dev` does not forward args through the nested workspace script).
- Use the browser console/network panel and Playwright MCP. Check Clerk configuration, `runtime-config.js`, the
  `/gateway` WebSocket, and TanStack Query cache keys before changing data code.
- Container: `docker build -t mission-control-web:local apps/web` (the build context is `apps/web`, and its
  `package-lock.json` is the app-scoped build lock; the root workspace lock is for local development).

### iOS

- Open `apps/ios/MissionControl.xcodeproj`; run the `MissionControl` scheme. Use `xcrun simctl install/launch` and
  `xcrun simctl spawn booted log stream` for a device without opening Xcode.
- Clerk redirect must be `com.kumarabd.MissionControl://callback`; the gateway authenticates with a fresh session token
  in the first WebSocket frame.
- Shared-code build failures usually mean a broken macOS symlink or a file missing from `apps/ios/MissionControl`.
- Xcode macro validation: use `-skipMacroValidation` only for reviewed packages.

### macOS

- `swift build && swift test` for the package; the Xcode app build uses the same symlinked sources.
- An unsigned Debug build may trigger a Keychain password prompt for the Clerk token; use the signed Release build for
  manual QA.
- Window capture works across Spaces: `screencapture -l <window-id>`; get the id with a small CoreGraphics script.
  AppleScript cannot send keystrokes without Accessibility permission, so prefer env-driven QA or direct clicks.
- If the app opens no window or looks stale, check `git status`, rebuild, and verify the `Shared` symlinks with
  `find apps/macos/Sources/MissionControl/Shared -type l` and `test -e`.

### Android

- Use JDK 21 from Android Studio's JBR. `local.properties` is machine-specific and ignored.
- Gradle 9.3.1, AGP 9.1.1, compileSdk 36.1, minSdk 24. The local machine may default to Java 8; always set
  `JAVA_HOME`.
- `adb logcat -s MissionVoice` for voice lifecycle; use the Android Auto Desktop Head Unit for the car surface.
- CI uses the Ubuntu runner's preinstalled Android SDK; do not reintroduce `android-actions/setup-android` (its
  `sdkmanager tools` call fails).

### CI

- Workflows: `web.yml`, `android.yml`, `foundations.yml`, `web-chart.yml`. Path filters keep client-only changes scoped.
- `gh run list -R kumarabd/mission-control`, `gh run view <id> --log-failed`, `gh run watch <id> --exit-status`.
- There is no image publish workflow. `web-chart.yml` publishes the standalone chart on `web-v*` tags or dispatch.
- The deployment chart is in `agent-harness`; it is applied from source, so changing it does not deploy by itself.

## Verification gate

Run at least:

```sh
make foundations
make web-check
make apple-check
make android-check
make ios-build
```

Expected current state: 110 web tests, 15 macOS tests, successful iOS simulator and macOS app builds, successful
Android debug build. Then look at the actual UI: Playwright for web (light and dark, `/` and `/docs`, no console
errors), the macOS window for desktop density, the iOS simulator for phone/iPad layouts. Check `git diff` for secrets,
generated-file drift and unrelated changes.

## Release and deployment

- **Web image:** built and pushed by the deployment pipeline. The Dockerfile is here; this repo does not publish the
  image.
- **Standalone chart:** `web-v*` tags or manual dispatch runs `.github/workflows/web-chart.yml`, which packages
  `apps/web/charts/agent-web` to `oci://ghcr.io/kumarabd/charts`.
- **Production web:** `agent-harness/deploy/helm/agent-harness-shared`, `agentWeb.image.repository:
  ghcr.io/kumarabd/mission-control-web`, tag `internal`. The chart has no web dependency. Change the image coordinate
  there; verify with `helm lint` and `helm template`. Do not Helm-upgrade until the image exists.
- **Apple:** signed Release builds are local; verify the bundle id, Clerk redirect and router before installing.
- **Android:** release signing and store distribution are not wired yet.

## Read next

- [docs/architecture.md](docs/architecture.md)
- [docs/parity.md](docs/parity.md)
- [design/README.md](design/README.md)
- [apps/web/README.md](apps/web/README.md)
- [apps/macos/README.md](apps/macos/README.md)
- [apps/ios/Tests/README.md](apps/ios/Tests/README.md)
- [docs/migrations/2026-10-monorepo-import.md](docs/migrations/2026-10-monorepo-import.md)
