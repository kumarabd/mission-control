---
title: Produce
group: Concepts
order: 6
summary: Produce an artifact and get it past a check, not past the model's own confidence.
status: extends
related: concepts/loops/transact, concepts/loops/diagnose
---

The check is the whole shape. For code it is tests and build, for documents explicit review criteria, and for creative work it is the user.

```loop
produce
```

**State.** A draft plus check results.
**Capabilities.** Read, plus reversible writes in its own workspace. Nothing that commits.
**Rails.** Done means the check passed. The model's confidence in its own draft never ends the loop.
**Exits.** Check green, user accepts, or budget.
**Handoffs.** To `transact` when the artifact feeds a submission.

> [!QUESTION]
> **Defining good.** Who decides what "good" is, and when? Defined per artifact class up front, or negotiated as drafting starts?

> [!QUESTION]
> **Delegation.** How much of this loop is delegation to a coding CLI versus in-loop editing?
