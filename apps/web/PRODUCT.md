# Product

<!-- impeccable:product-schema 1 -->

## Platform
web

## Users
Ordinary people who want a personal assistant and companion for everyday life: help with decisions, thinking, delegated work and continuing intentions. Mission Control is the place to create and manage those assistants. The authenticated web app also provides their conversations, memory inspection, connections, settings and recorded activity.

## Product Purpose
Offer a personal assistant and companion platform, supported by agent-harness (durable execution and tools), agent-brain (continuing memory), life-engine (explicit personal records), and first-party web and native clients. Goals, tasks, questions and everyday intentions can lead to different forms of help: conversation, delegated work, personal trackers and ongoing routines/reminders. Goal planning is one application of this broader intent-led companion platform.

## Positioning
A home for personal AI companions people can shape. The owner refined the landing direction on 2026-10-17: six beats told through five product-native scenes, without literal What / Why / How labels — continuity across devices, inspectable memory, a visible permission/provider boundary, a useful artifact, multiple companions and a local creation preview. Privacy, data ownership, governance and model flexibility carry the why. Copy stays minimal; the UI labels inside each scene are illustrative content, not additional claims. Depth lives at `/privacy` (account boundary, egress, controls, next directions), `/capabilities` (availability matrix) and `/docs` (technical detail). Multiple companions have separate instructions and memory banks within the account workspace; independent environments remain a future direction.

## Operating Context
- Clerk identifies the account. The router directs authenticated traffic to its provisioned workspace. Signup and early access are the same platform entry; setup provisions the workspace before use.
- Current provisioning is one workspace per account. Multiple standing assistant identities have names, instructions and separate memory banks, derived by the harness as tenant:agent_id. Workspace infrastructure, connections and model settings may be shared across identities.
- The harness runs durable conversations and delegated tasks, with configured approvals and interruption handling. Tasks can continue after the client closes; they may finish, need input, fail or be cancelled.
- agent-brain retains, recalls and reflects on conversation context. Semantic references are supporting document inputs where recorded, not automatic per-claim evidence. Memory is separate from explicit goals, plan items and observations in Life Engine.
- Life Engine provides goals, daily plans, routines, reminder occurrences, schedules, captures, notes, journal records and change history. Presence in the engine does not imply a corresponding screen in every client.
- Wakes/schedules and supported events provide proactive primitives. Do not resurrect removed intentions or user-selected conversational skill modes in public copy.

## Capabilities and Constraints
- Web: conversation, persona creation/selection, memory views, connections, recorded audit and model settings. Goals and tailored trackers are strongest in the native iPhone/iPad client; web parity is not implied.
- Native goal tracker rollout and live use were owner-confirmed on 2026-10-14. Semantic Memory views, integrated proactive experiences, model-setting parity and real push delivery have separate rollout/verification checkpoints; code or a build is not proof that every tenant can use them.
- Account-private data services, database/storage, authenticated routing and selected network policies exist. Shared routing/orchestration and external model/service processing remain part of the architecture.
- Custom model/provider credentials and setup secrets are implemented. These are not evidence of customer-managed encryption keys, operator-blind execution or end-to-end encryption. Independent computers per assistant, stronger key controls, data-lifecycle policy and additional devices are future directions unless verified separately.
- Stack: React 19, Vite, Tailwind 4, Radix, TanStack Query, assistant-ui, anime.js for the landing's scroll and component motion, Hanken Grotesk and IBM Plex Mono.

## Brand Commitments
Mission Control is the visible platform name. Preserve the existing sage accent, warm light surfaces and ink-dark mode. The public page demonstrates the story visually, with scroll-driven scene reveals, calm continuous loops and a local creation preview. The owner explicitly removed the Pause stories control; OS reduced-motion alternatives remain readable; technical detail stays optional. Examples must be explicitly illustrative and make no private-data or real-action calls. No fabricated testimonials, user counts, savings, release dates, unlimited-use promises or competitor-exclusivity claims.

## Evidence on Hand
Implementation sources: sibling agent-harness, agent-brain, life-engine and mission-control repositories. Canonical native and Life Engine checkpoints remain in sibling project-hub/projects/{mission-control,life-engine}/. This file describes product context, not a replacement for those implementation records.

## Product Principles
1. Introduce what a person can create before explaining how it is built.
2. Make each reason concrete: protection, agency, attention, perspective, capacity, follow-through and familiar support.
3. Show continuity through the same companion across different activities.
4. Separate account isolation from per-assistant identity and from encryption guarantees.
5. Explain where information goes, including configured providers and connected services.
6. Claims about approvals are scoped to configured policy/tool coverage; never guarantee detection of every consequential action.
7. Distinguish implemented, deployed, verified, preview and planned behavior. Do not imply current availability from an animation.
