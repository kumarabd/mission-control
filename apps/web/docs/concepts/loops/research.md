---
title: Research
group: Concepts
order: 5
summary: Answer a question well enough to act on, with sources attached to each claim.
status: extends
related: concepts/loops/diagnose, concepts/loops/transact
---

The deliverable is a document, not a chat answer, and breadth is the point. This is the one engine where parallel read subagents are clearly legitimate.

```loop
research
```

**State.** A coverage outline plus per-claim source notes.
**Capabilities.** Read only.
**Rails.** The deliverable is a document, not a chat answer. Claims carry their sources.
**Exits.** Coverage met and the artifact delivered, or the user stops it. Raised ceiling.
**Handoffs.** To `transact` when the user says "now do it".

> [!QUESTION]
> **Coverage.** How formal is "coverage"? A drafted checklist the user can read mid-flight, or the model's judgment sitting behind the finished artifact?

> [!QUESTION]
> **Artifact home.** Where does the report live: session files with a delivered attachment, or its own store?

> [!QUESTION]
> **A review against goals.** A one-off "how is my budget doing this month" has no engine of its own now that `tend` is a trigger. It lands here, whose skeleton is heavier than a glance. Is the answer a "measure against goals" variant of this brief?
