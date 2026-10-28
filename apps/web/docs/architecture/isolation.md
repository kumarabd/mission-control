---
title: Isolation
group: Architecture
order: 2
summary: Account-private resources, shared platform services, and where information leaves the workspace.
related: architecture/topology, concepts/memory, concepts/approvals
---

# Isolation

The deployed design gives each account its own data services, credentials and persistent storage. It is a hosted private workspace within a platform that also has shared services. This is not the same as all processing staying on the user's device, an independent machine for every assistant, or end-to-end encryption.

## Account boundaries

| Layer | Current design |
| --- | --- |
| Application services | Tenant services in the account's Kubernetes namespace, reached through authenticated identity routing. |
| Database/storage | A dedicated Postgres instance and persistent volumes for the tenant's data. |
| Execution | Tenant workers handle content and credentials; a shared loop-worker pool orchestrates workflows. |
| Workflow service | Shared Temporal infrastructure with tenant-specific activity queues and identifiers. |
| Assistant identity | Distinct names, instructions and memory banks within the account; not a separate infrastructure boundary per persona. |

Selected services have network policies. Their protection depends on deployment settings and a network implementation that actually enforces those policies. The presence of a YAML policy is not independent security verification.

## Shared infrastructure

Authentication/routing and orchestration have shared components. Workflow activities use references to keep content in tenant services rather than placing raw messages, tool arguments and results into the shared workflow layer on its ordinary path. Identifiers and orchestration metadata remain visible there.

Shared services also create shared availability risks: a failure in the orchestration pool can affect several accounts. Dedicated data services require backup, upgrade and recovery operations. Hosting still involves platform operational access; account isolation does not establish that operators are cryptographically unable to access data.

## External processing

Configured model and embedding providers process the context sent to them. Connected services receive authorized requests and their necessary data. Gateway identity services and any enabled operational services have their own processing roles. Do not describe model inference as the only possible egress or claim that an API key prevents provider access to the prompt.

## Keys and permissions

Model API credentials, database passwords, signing secrets, encryption-at-rest keys and end-to-end encryption are different mechanisms. Custom model credentials and setup secrets are implemented. Customer-managed encryption-key lifecycle and stronger end-to-end protections are future directions, not established by those credentials.

Configured approvals can govern specific actions, with policy/tool coverage and documented limitations. See [Approvals](/docs/concepts/approvals). This architectural explanation is not a legal privacy policy or a security certification.
