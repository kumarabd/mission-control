---
title: Conversation
group: Concepts
order: 1
summary: The surface. The one voice to the user, and the default every request lands in.
status: extends
related: concepts/loops/companion, concepts/loops/transact
---

Every request enters here, and every engine ends by handing a notice back here. It is today's top-level turn, and it stays the only thing that ever speaks to the user.

```loop
conversation
```

**State.** The transcript, plus a read-only list of the tasks running behind it, so "how is it going?" needs no tool.
**Capabilities.** Read and reversible micro-writes only: recall, history search, reminders, notes, and the control tools that start, amend or cancel a task. It holds nothing that commits.
**Rails.** Today's: approval gating, iteration ceiling, token budget, compaction. New: an engine's notice can queue behind an active turn but can never authorize work.
**Exits.** Answered, blocked on the user, or budget.
**Handoffs.** To any engine when a task is demanded. Every engine hands back to it with a notice.

> [!NOTE]
> **Told what exists.** A surface with few tools must be told what it can delegate. A production report from the harness's own history: the model had a tool in its schema, made no call, and told the user it could not do the thing, because its prompt never said it had capabilities.

> [!QUESTION]
> **Declining a classification.** When the classifier proposes an engine and the surface answers directly instead, that disagreement is logged. Is it an error, or the most useful evaluation signal there is?
