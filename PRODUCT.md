# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Stack
SwiftUI, iOS 17+, iPhone first. Existing hand-maintained Xcode project (synchronized folder `MissionControl/`).

## Users
First the owner, then the general public: a busy person managing work and life who opens the app in short check-ins (morning plan, midday adjustment, evening close), mostly one-handed on iPhone and often by voice.

## Product Purpose
A personal productivity companion that helps the user make progress on goals they care about, decide what deserves their time today, stop carrying commitments in their head, understand their day, stay consistent when life is messy, and remember what happened and what worked.

## Positioning
It adapts the plan when life changes. One quick capture becomes a task, reminder, diary entry or saved memory; "my day changed" revises the day; "I have 20 minutes" picks the next useful action; "close the day" records progress and clears unfinished commitments.

## Operating Context
Short sessions throughout the day, glanceable first, voice or one-line capture, notifications at user-chosen moments. Calendar events and tasks share one realistic day. Data lives server-side in the user's router workspace (Clerk sign-in, provisioning onboarding shared with Treasure and AutoTelemetry). The original Mission Control assistant dashboard is kept as the "Classic" tab.

## Capabilities and Constraints
Goal follow-through, realistic daily plan, life-admin capture and reminders, purposeful journaling, flexible routines (short versions, easy restarts), personal memory and weekly review. The backend productivity service does not exist yet; the client runs on an in-memory fake engine until it does.

## Brand Commitments
Name "Mission Control". Existing sage-green palette (`MissionTheme`), Hanken Grotesk text, IBM Plex Mono for small labels.

## Evidence on Hand
No testimonials, metrics or customers exist; none may be invented.

## Product Principles
1. One next action beats a full list: always show what to do now.
2. Capture is instant; organization happens afterwards, on the app's side.
3. A missed day is information, not failure: restart, shrink, never scold.
4. Plans must be realistic: fewer, smaller commitments.
5. Private by default: the journal is the user's.

## Accessibility & Inclusion
Dynamic Type everywhere, VoiceOver labels, 44pt targets, Reduce Motion, high-contrast variants (already in `MissionTheme`), voice as an equal input path.
