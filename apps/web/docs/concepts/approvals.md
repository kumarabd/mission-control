---
title: Approvals
group: Concepts
order: 4
summary: How a configured action can wait for a specific decision, and the limits of that permission boundary.
related: concepts/the-agent, concepts/proactivity
---

# Approvals

An assistant that uses tools needs a boundary between what may run and what requires your input. The harness has a permission-list mechanism that can gate configured tool actions.

## A specific decision

For a gated action, the server presents the stored action and its arguments for approval or refusal. The model does not get to rewrite the approval card into a different promise. The turn waits durably for the response and records the decision.

Refusal is a normal outcome. It does not mean the action was carried out. A question that asks for missing information is different from an approval that authorizes an action.

## Coverage is configured

Approval rules and task profiles determine which tools are offered and which actions need a card. Some operations are not on an approval list. Shell command matching has documented limitations, including compound commands and wrappers. Nested subagent input visibility also has limitations.

For those reasons, a working approval mechanism is not a guarantee that every consequential operation will be recognized and gated. Review the actual configured tools and permission coverage before entrusting sensitive work. A future self-service policy interface is not implied by today's backend mechanisms.

## Client behavior

The web chat can render and respond to supported pending-input cards. Other channels and notification paths have their own implementation and live-verification status. A static landing-page example never grants real authorization or invokes an external operation.
