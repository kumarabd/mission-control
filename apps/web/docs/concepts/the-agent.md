---
title: Your companion
group: Concepts
order: 1
summary: What a personal companion is, what Mission Control brings together, and how the system supports it.
related: concepts/memory, concepts/approvals, guides/getting-started, architecture/topology
---

# Your companion

Mission Control is a place to create and manage personal AI assistants and companions. You can ask for practical help, hand over work, or talk through a decision. What you share can provide useful context for later conversations.

## Make it personal

An assistant is a continuing identity with a name, instructions and its own memory bank. You can create more than one. These identities currently live in your account's provisioned workspace; they do not each have a separate computer, database instance or independent set of connected accounts.

## Different kinds of help

- Conversation and a useful second perspective.
- Research, comparison and drafting through configured tools.
- Goals, plans, routines and reminders supported by Life Engine and the relevant client.
- Scheduled and proactive help through configured triggers, with release availability that varies by integration.

The same platform supports these experiences, but every capability is not available as a screen on every device. The public examples use fictional data; they do not run tasks or access your accounts.

## What continues when you leave

The harness records and runs work through durable workflows rather than keeping it inside a browser request. Delegated work can continue after you close the app. A task can finish, ask for input, fail or stop; durability is not a promise of a successful result or instant recovery from every failure.

## Your choices and boundaries

You can inspect supported memory and recorded activity, choose connections and configure supported models. Actions on a configured approval list ask for a specific decision. Approval coverage depends on policy and tools; it is not a guarantee that every sensitive action is automatically recognized.

Your account has its own data services and storage, while some platform services are shared. Information sent for inference or to a connected service is processed there. See [Isolation](/docs/architecture/isolation) for the boundaries and [Approvals](/docs/concepts/approvals) for the permission mechanism.
