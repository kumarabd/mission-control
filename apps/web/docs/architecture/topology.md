---
title: Topology
group: Architecture
order: 1
summary: The path a message takes from a device to an answer, and which piece owns which decision.
related: architecture/isolation, architecture/delegation
---

# Topology

This page follows one message from a device to an answer. Each hop exists because
something had to be pulled out of the hop before it.

## What each hop owns

**Router.** The identity boundary. It resolves who you are and routes to your stack.
Nothing downstream needs to re-derive identity from a raw request.

**Gateway.** Ingestion and normalization. It accepts a message from any channel,
deduplicates it, resolves which session it belongs to, and durably hands it on. It
does not run the loop.

Splitting ingestion from execution is what makes the system survivable. A gateway
replica can be replaced without losing an in-flight turn, because the gateway's only
obligation is to get the message into durable storage.

**Coordinator.** Owns one session. It decides whether an incoming message starts a
turn or queues behind the one already running, and it exits after a period of
inactivity. It is the piece that makes "one turn at a time per session" a property of
the system rather than a convention.

**Turn workflow.** The loop itself. It is stateless with respect to tenant content:
it sequences activity calls and holds identifiers, while the activities that actually
touch your data run elsewhere. See [Isolation](/docs/architecture/isolation) for why
that split is deliberate.

**Workers.** Two fleets, with different jobs. The loop workers run the workflow code
and never hold your content. The tenant workers perform every activity that touches
your database, your files, or your credentials.

**State.** One Postgres instance per account holds structured state. Long-term memory
is a separate service behind its own tools, described in [Memory](/docs/concepts/memory).

**Delivery.** A separate path from ingestion, not the same round trip reversed. This
matters when a turn is started by a scheduled wake rather than by a message: there is
still somewhere for the answer to go.

## Why it is shaped this way

Three decisions explain most of the shape.

1. **Execution is separated from ingestion**, so a long turn does not occupy the
   thing that accepts your messages.
2. **The loop is separated from the work**, so the reasoning layer stays generic and
   the data-touching layer stays isolated.
3. **Work that outlives a request is durable**, so restarts, cancellations and long
   waits are normal operation rather than failure modes.

## Where the model sits

The model is a dependency behind one activity, not the center of the diagram. Swapping
it changes a call site, not the topology. That is the point of describing the agent as
an orchestrator rather than as a model with tools attached.
