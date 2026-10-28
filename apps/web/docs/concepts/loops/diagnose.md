---
title: Diagnose
group: Concepts
order: 4
summary: Find out why something is broken, and prove the cause before proposing a fix.
status: extends
related: concepts/loops/research, concepts/loops/stabilize
---

Diagnosis is iterative by nature, so this engine is allowed a raised ceiling and is held to a harder standard than most: a pass that learns nothing is a failure. It stays separate from `research`, even though both are read-only and both end in a claim with evidence. Their iteration drivers differ, information gain here and coverage gaps there, and so do the step prompts that follow.

```loop
diagnose
```

**State.** A hypothesis ledger: open or eliminated, plus the evidence that did it, and the current investigation point. A pinned scratchpad template rather than free prose.
**Capabilities.** Read only.
**Rails.** An iteration that neither adds evidence nor eliminates a hypothesis forces reassessment, then fails loudly. A diagnosis needs a reproduction or a confirmation step before it can submit.
**Exits.** A verified cause, a declared impasse, or budget on a raised ceiling.
**Handoffs.** To `produce` to implement the fix, or to `transact` to run a known remedy.

> [!QUESTION]
> **Ledger schema.** A fixed markdown table, which parses deterministically but is uglier to read, or model-authored with required sections, which is flexible and unparseable?

> [!QUESTION]
> **Falsification.** Should the rail force an explicit falsification attempt before submit, or is a reproduction enough?
