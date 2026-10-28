#!/usr/bin/env bash
# Keep the native font bundles identical to design/fonts.
#
#   ./scripts/sync-fonts.sh           copy the canonical fonts into both Apple clients and Android
#   ./scripts/sync-fonts.sh --check   fail if a bundled copy has drifted
#
# Web uses the @fontsource packages for the same families; the design system names
# the families and weights, so it does not need a third copy in public/.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
source_dir="$root/design/fonts"
check=false
if [[ "${1:-}" == "--check" ]]; then
  check=true
fi

pairs=(
  "HankenGrotesk-Variable.ttf:$root/apps/ios/MissionControl/Resources/Fonts/HankenGrotesk-Variable.ttf"
  "IBMPlexMono-Regular.ttf:$root/apps/ios/MissionControl/Resources/Fonts/IBMPlexMono-Regular.ttf"
  "IBMPlexMono-Medium.ttf:$root/apps/ios/MissionControl/Resources/Fonts/IBMPlexMono-Medium.ttf"
  "HankenGrotesk-Variable.ttf:$root/apps/macos/Sources/MissionControl/Resources/Fonts/HankenGrotesk-Variable.ttf"
  "IBMPlexMono-Regular.ttf:$root/apps/macos/Sources/MissionControl/Resources/Fonts/IBMPlexMono-Regular.ttf"
  "IBMPlexMono-Medium.ttf:$root/apps/macos/Sources/MissionControl/Resources/Fonts/IBMPlexMono-Medium.ttf"
  "HankenGrotesk-Variable.ttf:$root/apps/android/app/src/main/res/font/hanken_grotesk.ttf"
  "IBMPlexMono-Regular.ttf:$root/apps/android/app/src/main/res/font/ibm_plex_mono_regular.ttf"
  "IBMPlexMono-Medium.ttf:$root/apps/android/app/src/main/res/font/ibm_plex_mono_medium.ttf"
)

failures=0
for pair in "${pairs[@]}"; do
  source="$source_dir/${pair%%:*}"
  destination="${pair#*:}"
  if [[ ! -f "$source" ]]; then
    echo "missing canonical font: $source"
    failures=$((failures + 1))
    continue
  fi
  if $check; then
    if [[ ! -f "$destination" ]] || ! cmp -s "$source" "$destination"; then
      echo "font drift: ${destination#"$root"/}"
      failures=$((failures + 1))
    fi
  else
    mkdir -p "$(dirname "$destination")"
    cp "$source" "$destination"
    echo "synced ${destination#"$root"/}"
  fi
done

if $check && [[ $failures -eq 0 ]]; then
  echo "fonts are up to date"
fi
exit "$failures"
