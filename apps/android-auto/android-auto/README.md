# Mission Control for Android Auto

This module is a driver-safe Android Auto **media** app for Mission Control
briefings. It intentionally does not expose a free-form chat interface.

## Current scope

- Android Auto discovers `BriefingMediaService` as a `MediaLibraryService`.
- Android Auto renders the browsing and playback interface itself, using the
  cached briefing catalog as the audio library.
- The phone surface reserves sign-in, setup, settings, full transcript access,
  and any tool approval for when the user is not driving.
- The phone signs in with the existing Clerk instance, fetches the private
  `GET /gateway/android/briefings` feed through the shared router, and caches
  only the audio-library projection.
- Each playback request includes the current Clerk bearer token. Tokens are
  held only in memory; the catalog cache contains no credentials.

## Before release

Enable Clerk's Native API for `org.nighthawklabs.missioncontrol` in the Clerk
Dashboard before making a production build. Do not add open-ended assistant
responses or destructive tool controls to the in-car surface; Android Auto does
not support a generic assistant/chat category.

## Test

Open the root project in Android Studio, select the `android-auto` module, and
use the Android Auto Desktop Head Unit to test the driver display.
