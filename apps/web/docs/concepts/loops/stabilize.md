---
title: Stabilize
group: Concepts
order: 8
summary: Stop something that is going wrong, before understanding it fully.
status: extends
related: concepts/loops/diagnose, concepts/loops/transact
---

The one engine that deliberately inverts the order of tool use: the first call stabilizes rather than investigates. The model still reasons, but about *which action to take*, not about *what the situation is*. Escalating to the user is an expected outcome here, not a failure.

```loop
stabilize
```

**State.** An incident log: what happened, what was tried, what is changing.
**Capabilities.** Read, plus reversible actions only. Anything that cannot be undone escalates to the user.
**Rails.** The inverted order is steered, not structural: a prompt section, a budget tight enough that an investigation would blow it, and a tool set that offers only reversible actions. Evidence is preserved for the hand-off.
**Exits.** A real-world check that the situation has stopped worsening, and follow-up scheduled. Full understanding moves to the hand-off engines.
**Handoffs.** To `diagnose` for root cause, to `transact` for the fix, and to a `watch` for the prevention.

> [!QUESTION]
> **A cheap, reversible action.** Entry requires one that plausibly stops the worsening. A cancelled flight is urgent, but its stabilizing move is a rebooking, which is a commitment. Does "hold or check alternatives" count, or is that case really `transact`?

> [!QUESTION]
> **Emergency budget.** Should this skip the usual approval for small spends, such as a taxi when stranded, under a pre-declared emergency budget?
