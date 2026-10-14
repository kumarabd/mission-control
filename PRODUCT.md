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
It adapts the plan when life changes. One quick capture becomes a task, reminder or routine. Today separates timed commitments from untimed work. Goals have tailored native trackers composed through Life Engine catalogs. Agent-memory-backed reflection remains a later discussion.

## Operating Context
Short sessions throughout the day, glanceable first, voice or one-line capture, notifications at user-chosen moments. Calendar events and tasks share one realistic day. Data lives server-side in the user's router workspace (Clerk sign-in, provisioning onboarding shared with Treasure and AutoTelemetry). Today, Goals and Memory are the main tabs. The original assistant dashboard is available from Settings.

## Capabilities and Constraints
Goals, daily tasks, timed reminders and flexible routines use Life Engine. Goal trackers use recorded numeric outcomes, one-off milestones and linked routine consistency; revisions are reviewed before use. Memory currently browses existing local records without direct save/edit controls. Agent-brain semantic views will power Reflections and About you; requests to remember or correct information go through the assistant. Journal and the local weekly review have been removed from the interface; existing stored records are retained.

## Brand Commitments
Name "Mission Control". Existing sage-green palette (`MissionTheme`), Hanken Grotesk text, IBM Plex Mono for small labels.

## Evidence on Hand
No testimonials, metrics or customers exist; none may be invented.

## Product Principles
1. Today answers when something happens and what remains to do: timed items belong in Schedule; untimed items belong in Tasks.
2. Capture is instant; organization happens afterwards, on the app's side.
3. A missed day is information, not failure: restart, shrink, never scold.
4. Plans must be realistic: fewer, smaller commitments.
5. Private by default: saved personal information is the user's.

## Accessibility & Inclusion
Dynamic Type everywhere, VoiceOver labels, 44pt targets, Reduce Motion, high-contrast variants (already in `MissionTheme`), voice as an equal input path.
