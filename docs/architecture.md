# Architecture

Mission Control is a monorepo for one product with several clients. Clients share contracts, design language and
release discipline; they do not share UI code or build systems.

## Layout

| Path | Role |
|------|------|
| `apps/web/` | Web console. React 19, Vite, TypeScript, Tailwind v4. Clerk auth, router/gateway/Life/memory clients. Public docs are in `apps/web/docs/`. |
| `apps/ios/` | iOS/iPadOS/CarPlay/watch application sources and the Xcode project. |
| `apps/macos/` | macOS console. SwiftUI shell plus a Swift package; shares the iOS Core/Features through `Sources/MissionControl/Shared` symlinks into `apps/ios/MissionControl/`. |
| `apps/android/` | Android app. Kotlin, Compose, Car App service, Clerk and the mobile gateway. Parity work is pending. |
| `design/` | Canonical app-icon sources and, from the shared-foundation step, fonts and tokens. |
| `docs/` | Repository documentation. The public product docs are separate, under `apps/web/docs/`. |

## Shared boundaries

- **Contracts:** the router, gateway, Life Engine, memory and notifications are the same services for every client.
  Wire shapes are currently hand-written per platform. A shared schema/fixture package is the next step; until then,
  changes to a wire shape must be made in every client and covered by its tests.
- **Design:** the palette, type families (Hanken Grotesk, IBM Plex Mono), spacing and motion follow one design system.
  The shared core palette is generated from `design/tokens.json` into CSS, Swift and Kotlin; `scripts/tokens.mjs
  --check` fails on drift. Fonts have one canonical copy under `design/fonts/`, synced into the native bundles. The
  web's `DESIGN.md` and the Apple `DESIGN.md` document each platform's implementation of the same system.
- **Configuration:** each platform keeps its native configuration mechanism (Vite env, Xcode build settings, Gradle
  properties). Values and redirect URIs are documented rather than generated. Secrets never enter the repository.
- **CI:** web, Android and foundations have path-scoped GitHub workflows. The web image publishes from
  `.github/workflows/web-image.yml` on `web-v*` tags to `ghcr.io/kumarabd/mission-control-web`; the standalone web
  chart publishes from `.github/workflows/web-chart.yml` to `oci://ghcr.io/kumarabd/charts`. The production deployment
  chart is the `agentWeb` template in `agent-harness/deploy/helm/agent-harness-shared`, which is applied from source
  and has no web dependency. Apple builds run locally with the commands in the root README and Makefile; macOS
  runners are optional because of cost.

## Data flow

The browser and the Apple/Android clients authenticate with Clerk, then call the shared router. The router verifies
the session and supplies the tenant identity to the Life Engine, memory and gateway. The Android and Apple clients
open the mobile gateway directly for a turn; the web uses the browser WebSocket through the router. Voice stays
on-device on Apple and Android.

## Build systems

- Web: npm workspaces at the repository root; one lockfile. `npm ci` then the workspace scripts.
- Android: one Gradle build in `apps/android`, wrapper-pinned, JDK 21.
- Apple: one iOS Xcode project in `apps/ios` plus the macOS Swift package/Xcode project in `apps/macos`.
  The macOS package symlinks the shared iOS sources, so both must move together if the Apple layout changes.
