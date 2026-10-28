---
title: Proactivity
group: Concepts
order: 5
summary: Scheduled and event-based help, the context it uses, and why availability depends on the complete delivery path.
related: concepts/the-agent, concepts/approvals
---

# Proactivity

Proactive help brings something useful back into view without requiring a fresh question at that moment. It needs context, an appropriate trigger and a working delivery path; it does not mean the assistant observes everything in your life.

## Different kinds of future help

- A reminder tells you about an explicit record or occurrence.
- A user-visible recurring prompt or review can be stored as a Life Engine schedule.
- A harness wake starts the assistant's reasoning at a configured time or in response to a supported event.
- A watch uses available tools or engine events to check a configured situation.

These are distinct from conversational memory. Mentioning an intention does not prove that a reminder or recurring review was created.

## What a wake does

A schedule fires a workflow that wakes the relevant session. The assistant can inspect available context and tools, produce useful output, ask for input or end without sending a message. Schedules are not a worker process sleeping until a deadline.

Engine notices, gateway inbox intake and notification delivery have separate responsibilities. Event support is integration-specific. Generic provider webhook delivery and universal cross-device notification support are not implied.

## Keep suggestions grounded

A suggestion should identify the context that informed it. “You mentioned wanting to reconnect with Alex” is only meaningful when that was actually shared. A repeated theme is an interpretation to discuss, not a diagnosis or a guaranteed discovery. Proposed plan changes remain proposals until accepted through the supported flow.

## Release status

The platform has scheduling, monitoring and wake primitives. An integrated consumer recommendation experience and reliable notification delivery require verification of the whole path. In the inspected rollout record, semantic-memory delivery and real APNs device delivery still have outstanding checks. Treat a deployed goal tracker, a passed sender test and a polished proactive example as different kinds of evidence.
