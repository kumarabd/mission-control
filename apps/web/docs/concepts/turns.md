---
title: Turns
group: Concepts
order: 2
summary: One reason, act, observe cycle from the message arriving to the answer being delivered.
related: concepts/memory, concepts/approvals
---

# Turns

A **turn** is one full pass through the loop: your message goes in, a result comes
out. Turns are the unit the rest of the console is built on, so runs, costs and
approvals are all reported per turn.

## Lifecycle

A turn moves through a small, fixed set of phases.

1. **Accept.** The message is attached to a session. If a turn is already running,
   the new message queues and signals an interrupt rather than starting a second loop.
2. **Assemble.** The system prompt is built from the standing instructions, the
   session's recent context, and anything the model previously retrieved.
3. **Loop.** The model reasons and acts, repeatedly, until a stop condition is met.
4. **Close.** The answer is persisted, delivered to whichever channel you used, and
   the session's content is written into long-term memory.

## Stop conditions

A loop that can only stop by deciding it is done is a loop that can run forever.
Four independent conditions end a turn:

- The model returns a final answer with no further tool calls.
- The budget for the turn is exhausted.
- A watchdog notices no progress across consecutive rounds.
- You interrupt it.

The watchdog matters most. A model repeating an identical failing call is not making
progress, and the orchestrator treats that as its own failure, not as something to
retry indefinitely.

## Asking instead of guessing

A turn can surface a question back to you and wait. This is different from an
approval: a question fills a gap the model cannot close on its own, while an approval
unlocks an action it is not allowed to take by itself.

Both are durable. The turn suspends, and it survives a restart while waiting.

## Delegation

Work that is long, or that needs a specialist, is handed to a child execution. The
parent turn keeps its own context and receives a structured summary back rather than
a raw stream of output. See [Delegation](/docs/architecture/delegation).
