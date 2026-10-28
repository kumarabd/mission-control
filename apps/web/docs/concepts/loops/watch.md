---
title: Watch
group: Concepts
order: 9
summary: A standing wake that carries an objective. It starts work later instead of doing it.
status: extends
related: concepts/proactivity, concepts/loops/research
---

This is what makes an assistant stop being one that answers and start being one that looks after things. It is a trigger, not an engine: a schedule or an event subscription with an objective attached. When it fires, the objective is classified like any request and runs as whichever engine it demands.

```loop
watch
```

A monthly budget review runs as `research`. An anomaly found runs as `diagnose`. Drift that needs fixing runs as `transact` or `produce`. A watch has no exit of its own, because the engine it launches carries the evidence.

**State.** Per-concern history, goals and open threads, durable across months. Every engine it launches can read it.
**Capabilities.** Setting one up is a reversible micro-write the surface can do, subject to the approval policy for standing commitments.
**Rails.** The wake machinery is the engine: `arm_wake` and `manage_wake` already exist, and a watch already carries an objective.
**Handoffs.** To any engine, by the labeled objective.

> [!WARNING]
> **Cross-session domain state.** The scratchpad is per-turn and sessions are long but finite. The candidates are a domain-state file in the session filesystem, memory backed by agent-brain, or a small per-domain store.

> [!QUESTION]
> **A one-off review.** A review of a standing concern that is not scheduled has no home of its own now. It lands on `research`. Is that a systematic misfit?

> [!QUESTION]
> **Cadence.** How does a concern earn its review cadence, and who quiets it?
