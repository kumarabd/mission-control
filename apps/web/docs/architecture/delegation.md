---
title: Delegation
group: Architecture
order: 3
summary: Why the agent hands long or specialist work to other CLIs instead of doing it itself.
related: concepts/turns, architecture/isolation
---

# Delegation

The agent is an orchestrator, not a coding agent. When a task needs one, it delegates
rather than growing the capability itself.

## Why not build it in

A general loop that also tries to be excellent at every specialist task ends up
mediocre at all of them. Specialist CLIs are better at their domains, they improve
without this codebase changing, and they already exist.

Keeping delegation as the contribution means the agent's job is the interesting part:
deciding what to delegate, giving it a clear scope, and deciding what to keep. Not
reimplementing a shell.

## How it works

A delegated task runs as a **child execution**, not as a blocking call inside the
parent turn.

1. The parent decides a task is worth delegating and gives it an explicit scope.
2. A child execution starts with that scope and its own working directory.
3. The parent turn continues, or suspends, without holding the work open.
4. When the child finishes, it returns a **structured summary**, not its raw output stream.

The parent's context stays clean. A specialist that produced ten thousand lines of
logs returns a few hundred tokens of result. Nothing else about its work enters the
parent's conversation.

## Failure semantics are sharper than a shell call

> [!WARNING]
> A delegated task succeeds or fails as a whole. There is no partial result to salvage
> from the tail of a stream, the way a shell command's output can be read.

The reason is that a child execution has its own lifecycle. A delegate that fails is a
fact about the task, not something to be reconstructed from whatever it printed first.

Delegation is also given a longer time budget than an ordinary tool call, because it
is genuinely doing more. Timing is expected to be measured in minutes.

## What the parent still does

Three things are explicitly kept, not delegated:

- **The decision to delegate**, including whether it is worth it at all.
- **The scope**, stated up front. A vague delegation is the failure mode that produces
  plausible-looking work nobody asked for.
- **Judgment on the result.** The summary is an observation the parent weighs, in the
  same way a recalled procedure is.

That last one is the same principle as memory: nothing that comes back from a
subsystem is executed on trust.
