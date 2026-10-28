---
title: Loops
group: Concepts
order: 6
summary: One conversation surface, five engines behind it, and standing triggers that start work later.
related: concepts/the-agent, concepts/turns, concepts/proactivity
---

Work comes in three kinds. The **surface** is the conversation the user talks to, and it is the only voice they ever hear. An **engine** is a task that runs behind it, with its own prompts, tools and a checkable exit. A **standing trigger** starts work later.

An engine is not a second runtime. It is the same reason-act loop run under a profile: prompt sections, a scratchpad template, tool provisioning, budget defaults, and at most two deterministic rails.

This is a draft. Nothing here is built, and the open questions are left visible rather than tidied away. Each shape has its own page, listed below. The set was condensed from eleven on 2026-10-11.

## How they run together

The surface and an engine run at the same time, so the user can keep talking while work happens. An engine never speaks to the user. It raises a typed notice, and the surface speaks it.

```loop
concurrent
```

The model proposes and the harness disposes, at two altitudes: which engine a piece of work is, and which state a running task moves to next. Both are choices from a closed menu the harness built, and the harness checks each against the principal, the capability table and the exit rules.

A task carries three principals. The **requester** asked, the **approver** may say yes to a commit and is normally the owner, and the **subject** is whose data it touches. Authority only ever narrows down a chain of delegation, and text from a restaurant or a tool result is data, never an instruction.

## Reading these diagrams

The notation is the same on every page of these docs:

- A **trigger** pill is what starts the shape.
- **States** are the boxes it passes through, left to right and top to bottom.
- A **parked** state, dashed in amber, is waiting on the world rather than working.
- The **exit**, dashed in the accent, is the evidence that "done" rests on.
- The **loop-back** edge, dashed, is labelled with what sends it round again.
- **Hand-offs** name the other shapes this one can turn into.

The one universal rail: **"done" is evidence, never the model's claim.** Each engine names the evidence it accepts, and a shape with no evidence to offer has no exit at all.

## The shared skeleton

Every shape is this, with different settings.

```loop
anatomy
```

## The surface

These run as the conversation itself. They change its prompt, its privacy treatment and its durable record, and never give it an engine's capabilities.

| shape | build | what it is |
| --- | --- | --- |
| [Conversation](/docs/concepts/loops/conversation) | `extends` | The default. Answers, looks things up, and delegates real work to an engine |
| [Companion](/docs/concepts/loops/companion) | `extends` | Reflective support with nothing to prove and no exit to reach |
| [Learn](/docs/concepts/loops/learn) | `extends&nbsp;+&nbsp;new` | Teach a skill, where progress means the learner did the exercise |

## The engines

Each one has a checkable exit and a capability tier, which decides the tools it is offered.

| engine | tier | exit rests on | build |
| --- | --- | --- | --- |
| [Diagnose](/docs/concepts/loops/diagnose) | read | a cause that reproduces or is confirmed by a test | `extends` |
| [Research](/docs/concepts/loops/research) | read | coverage of the question's scope, sources per claim | `extends` |
| [Produce](/docs/concepts/loops/produce) | read + micro-write | a check result: tests, review, or the user's acceptance | `extends` |
| [Transact](/docs/concepts/loops/transact) | read + commit | the counterparty's attestation | `extends&nbsp;+&nbsp;new` |
| [Stabilize](/docs/concepts/loops/stabilize) | read + reversible commit | the situation has stopped worsening | `extends` |

## The trigger

| shape | build | what it is |
| --- | --- | --- |
| [Watch](/docs/concepts/loops/watch) | `extends` | A standing wake with an objective. When it fires, the objective is classified like any request |

`exists` runs on today's machinery. `extends` adds prompt, state and rails to it. `new` needs machinery the harness does not have yet.

## Why eleven became five

A shape earns an engine only if it has an **exit the harness can check**, independent of the conversation. Work whose exit is that the user led away, that the user did the exercise, or that the next review is scheduled has no such exit, so it is a surface profile or a trigger.

Three engines are merged and two are kept apart on purpose:

- **Transact** is arranging, acquiring and executing. After evaluation they share one skeleton, one capability tier and one kind of exit, an attestation by a party outside the system. What distinguished them survives as a variant of the brief.
- **Diagnose** and **research** stay separate. They differ on what drives another pass, and on the step prompts that follow.

## What the shapes have in common

### Cross-session state is the real build

`watch`, `learn`, `companion`, and the waiting lists of `transact` all keep state that outlives a turn. Today's durable state is the transcript, and the scratchpad is per-turn. The candidate homes, whether session-filesystem files, agent-brain memory, or a small per-domain store, are one design decision and probably the same one for all of them.

### Dormant waiting is its own primitive

Waiting on the restaurant, the courier or the institution is a first-class state in `transact`. Nothing in the harness parks a task and resumes it on an external event today. That is one primitive with one main consumer.

### Hand-offs between shapes

| from | to | when |
| --- | --- | --- |
| `stabilize` | `diagnose` | the situation is stable, so find the root cause |
| `stabilize` | `transact` | the crisis is a booking, purchase or plan problem |
| `stabilize` | `watch` | prevent the recurrence |
| `watch` (fired) | any engine | by the labeled objective |
| `research` | `transact` | the user says "now do it" |
| `diagnose` | `produce` / `transact` | cause found, so implement or run the fix |
| `produce` | `transact` | the artifact feeds a submission |
| `conversation` / `companion` | `transact` | a real-world need surfaces |
| any engine | `conversation` | exit, blocked or failed: every task ends in a notice |

### Budgets follow the shape

Iteration ceilings and token budgets should not be uniform. `diagnose` and `research` are iterative by nature and need raised ceilings, `stabilize` wants a tight budget and fast escalation, and `conversation` keeps today's defaults.

> [!WARNING]
> **The harness has built this before.** A classifier and lane router were removed in September 2026, and a session-mode mechanism with a separate step runtime was built and removed in October. This design reuses the parts that were sound, such as completion evidence, exact approval text and revisions on every command, and avoids the second runtime. Why the second removal happened is not recorded.

> [!QUESTION]
> **A one-off review of a standing concern.** With `tend` now a trigger, "how is my budget doing this month" lands on `research`, whose skeleton is heavier than the question. A "measure against goals" variant of that brief may be the fix.
