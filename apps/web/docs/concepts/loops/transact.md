---
title: Transact
group: Concepts
order: 7
summary: Do something in the world and confirm the other side agrees it happened.
status: extends + new
related: concepts/loops/produce, concepts/loops/stabilize
---

Transacting is not over when the decision is made. It is over when somebody else attests, which is what makes waiting a first-class state here. A reservation, a purchase and a filed procedure share this one skeleton, and differ only in what the attestation is.

```loop
transact
```

| variant | the plan comes from | the exit rests on | what trails the commit |
| --- | --- | --- | --- |
| arrangement | options and comparison | a booking number or confirmation | a reschedule loop and a waiting-on list |
| acquisition | existing products | **the delivered item matches the spec**, not the order and not the shipment | fulfillment tracking, returns |
| procedure | a **template**, pre-compiled and deadline-driven | the institution's acknowledgement of submission | a document checklist and deadlines |

The variant is a parameter of the brief, not a separate loop. After the evaluation step the three share one skeleton, one capability tier and one kind of exit: an attestation by a party outside the system.

**State.** A constraint or spec ledger, an option comparison, and a waiting-on list, plus a purchase tail or a procedure checklist depending on the variant.
**Capabilities.** Read, plus committing actions. Every commit is behind an approval gate.
**Rails.** An approval on every commitment, and every commitment ends with an attestation rather than a claim. Mutations get one attempt: an ambiguous write is never retried or reported as successful.
**Exits.** Attested and verified, abandoned, or the user takes over.
**Handoffs.** From `stabilize`, when a crisis turns out to be a task, and from `produce`, when an artifact feeds a submission.

> [!WARNING]
> **Dormant waiting.** The task parks on "waiting for the restaurant to confirm" and resumes when the reply arrives. Today a turn ends and only messages or wakes restart activity, so park-and-resume needs a designed path through the coordinator.

> [!QUESTION]
> **One skeleton or three?** This merge is the one most likely to need re-splitting if the step prompts for the variants diverge more than the table above suggests. It should be tested against the boundary drills before anything is built.

> [!QUESTION]
> **Constraint elicitation and nudging.** How many rounds of asking before it feels like an interrogation, and what is the nudge policy while waiting: silence by default, or a note on delivery day?
