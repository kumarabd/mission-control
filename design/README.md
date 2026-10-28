# Shared design assets

This directory is the single source for assets that must stay identical across clients.

## Tokens

`tokens.json` is the core semantic palette: `canvas`, `surface`, `raised`, `ink`, `quietText`, `line`, `tint`,
`actionInk`, `scheduled`, `attention`, `reminder`, `telemetry`, `health`, `success` and `graphCanvas`, each with
`light`, `dark`, `lightContrast` and `darkContrast`.

Regenerate the platform files after editing it:

```sh
make tokens       # or: node scripts/tokens.mjs
make foundations  # check for drift without writing
```

Generated consumers:

| Platform | File |
|----------|------|
| Web | `apps/web/src/tokens.generated.css` (imported by `themes.css`) |
| iOS + macOS | the generated block inside `apps/ios/MissionControl/UI/MissionTheme.swift` |
| Android | `apps/android/app/src/main/java/org/nighthawklabs/missioncontrol/ui/theme/DesignTokens.kt` |

Do not edit the generated file or the marked Swift block. Platform-only roles (muted tints, shadows, scrims and the
web's extra semantic roles) stay hand-authored in the client.

## Fonts

`design/fonts/` holds the canonical Hanken Grotesk variable font and IBM Plex Mono regular/medium, with their OFL
licenses. `scripts/sync-fonts.sh` copies them into both Apple bundles and Android's `res/font` (renaming to Android's
snake_case resource names). The web uses the `@fontsource` packages for the same families.

```sh
make fonts        # copy canonical fonts into the native bundles
make foundations  # fail if any bundled copy has drifted
```

## Icons

`app-icons/source/` holds the SVG sources for the iOS, macOS and Android app marks. Export platform assets from
these sources; keep the generated icon sets in the platform projects.
