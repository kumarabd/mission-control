---
title: Memory
group: Concepts
order: 3
summary: How shared context can help later conversations, and what the memory views do and do not mean.
related: concepts/the-agent, architecture/isolation
---

# Memory

Memory helps a companion build on what you have shared: a preference, a recurring question or context from an earlier conversation. It can be useful without being complete or infallible.

## Conversation context and explicit records

The harness sends conversation material to agent-brain's retain pipeline and can use recall and reflection tools when reasoning. The memory service maintains retained units, observations, entities and personal models. Current harness bank IDs distinguish standing assistant identities within an account.

An explicit goal, reminder, plan item or measured outcome is a different kind of record, owned by Life Engine. A remembered intention is not automatically a scheduled reminder, and a planned target is not evidence that work was completed.

## Looking at what is remembered

The web and native clients show the World lens: the people, places and things the assistant knows about, and how they connect. Entity drill-downs and supporting references come from purpose-built reads for facts, entities, links and a bank profile. About you is planned but not yet available; Reflections is not currently shown. Client coverage and configured-bank mapping matter; a backend endpoint does not imply every view supports arbitrary assistant-bank selection.

Some semantic content includes supporting memory references. These identify document inputs where recorded, not evidence for every sentence. Legacy content may have no recorded reference; missing or unavailable sources should be shown honestly.

## Discussing a correction

You can provide a correction or ask about remembered information through a conversation. Direct edit, forget, export and retention controls are not universal across the current clients and services. Do not assume that deleting a chat removes every derived memory or personal record.

## Where it is processed

The account's memory service is part of its private workspace. Retaining, embedding, recalling or reflecting can involve configured model or embedding endpoints. Context sent to those providers leaves that workspace for processing. The relevant provider and deployment settings determine the processing boundary.
