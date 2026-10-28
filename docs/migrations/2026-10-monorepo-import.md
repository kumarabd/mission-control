# 2026-10 monorepo import

The web console and the Android app now live with the Apple clients in `mission-control`.

## Imported

- `~/Documents/agent-web` → `apps/web` (product tree: `src/`, `public/`, `docs/`, configs, container files,
  Helm chart, `PRODUCT.md`, `DESIGN.md`). The snapshot includes the working-tree graph changes that were not yet
  committed.
- `~/AndroidStudioProjects/MissionControl` → `apps/android` (sources, resources, Gradle wrapper and build files only).
  The project had no git history.

## Removed

- `apps/webapp` — an unrelated portfolio/PSS prototype; not the Mission Control client.
- `apps/android-auto` — a source-less media stub; the Android app already has a Car App service.
- Not imported from `agent-web`: `plans/`, `brag-output*`, `graphify-out/`, `.claude/`, `.agents/`, `.hermes/`,
  `.codex/`, `.impeccable/`, `.taste-skill/`, `.playwright-mcp/`, `node_modules/`, `dist/`, and the duplicate agent
  tooling binaries. The landing surface brief referenced by `apps/web/DESIGN.md` was kept at
  `apps/web/docs/design/landing-surface.md`.

## Root changes

- npm workspace `@mission-control/web`; one root lockfile; root `dev`/`lint`/`test`/`typecheck`/`build` scripts.
- Root `.gitignore`, `.dockerignore`, `.editorconfig`, `.gitattributes`, `.nvmrc`.
- `Makefile` for web, Android and Apple checks.
- Path-scoped GitHub workflows: `.github/workflows/web.yml`, `.github/workflows/android.yml`.
- `docs/architecture.md`, `docs/parity.md`, and a root README that points at every client.
- The web Dockerfile now builds from the repository root; compose uses the root context.
- The web image publishes from `.github/workflows/web-image.yml` on `web-v*` tags to
  `ghcr.io/kumarabd/mission-control-web`; the Helm chart defaults its tag to `Chart.appVersion` (`0.1.0`).
  The first release (`web-v0.1.0`) still needs to be tagged to produce that image.
- Android's Clerk publishable key moved out of `app/build.gradle.kts` into a Gradle property.
- The iOS project and sources moved to `apps/ios`; the macOS `Shared` symlinks now point into
  `apps/ios/MissionControl/`.
- `design/tokens.json` generates the core palette into CSS, Swift and Kotlin; `design/fonts/` is the canonical font
  set. `make tokens`, `make fonts` and `make foundations` manage them.

## Verification

- Web: `npm ci`; lint (one pre-existing warning); typecheck; 110 tests; production build; dev server; Playwright
  smoke of `/` and `/docs` with no console errors; container build and HTTP smoke.
- Android: JDK 21, `:app:testDebugUnitTest` and `:app:assembleDebug` from `apps/android`.
- Apple: the iOS simulator build and the macOS Swift package (15 tests) and Xcode app build all pass after the move;
  the pre-existing macOS/iOS working-tree changes were committed as a checkpoint first.

## Still to do

1. Android feature parity against the shared contracts.
