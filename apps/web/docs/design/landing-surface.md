---
version: 1
slug: "src-pages-landing-tsx"
primary_target: "src/pages/Landing.tsx"
related_targets: ["src/features/landing/landing.css", "src/features/landing/StoryScenes.tsx"]
---

# Public landing

> Current implementation: the landing story v2 plan (in the former agent-web repository's history). On 2026-10-17 the owner approved five product-native scenes — continuity, memory, boundary, companions, artifact — with anime.js scroll and component motion, minimal copy and a local creation preview. The direction contract below predates that content revision; the palette, type and brand commitments still hold.

Mode: Persuade. Audience: ordinary people seeking a personal assistant and companion. Action: early-access signup, or return to an existing workspace. On 2026-10-16 the owner explicitly replaced the literal What / Why / How partitions and single-transition restraint with an animated visual story. Preserve the conceptual offer → value → getting started sequence, not its labels. The latest owner correction explicitly asks for a fancy, animation-heavy scroll experience, moving page elements and continuous story loops; this extends the established identity, with no new palette or brand workshop. No production deployment requested.

## Direction contract

THESIS: Show a personal companion coming to life and helping across daily life before asking a visitor to read an explanation. One continuing Mira identity links intentions, useful output, context, user agency and personal creation.

OWN-WORLD: Inherit paper / ink-dark surfaces, sage signal color, Hanken Grotesk and the house line icons. Expand the existing world with layered functional UI scenes, fine animated connections, varied open bands, physical card assembly and approachable large lettering. Code-led; no approved raster comp or stock illustration.

STORY: One Spanish-learning intention→companion→tailored tracker, routine and chosen reminders; distinct daily-plan, draft, reflection and chosen-check-in examples; a question and shared context becoming a personal weekly view (product preview); a visible privacy boundary with a local context switch; shaping a companion through name/style; honest availability and optional details; real signup.

FIRST VIEWPORT: Preserve the companion-first headline, signup and large functional hero. The hero keeps one intention visible while its output cycles through a tracker, routine and reminders every6.2seconds. Other scenarios appear once in the day section. Redundant day introductions/recaps and mindspace supporting slogans are removed. A new kinetic bridge carries “Think together.” and “Make room for life.” on opposing scroll tracks, with the companion mark and a drawn connecting thread. Mobile reflows without nested scrollers or clipped controls.

FORM: Inherited direction seed dfe9db78, extended by the owner’s explicit correction after rejecting the quieter macro-motion pass. Larger scenes move throughout viewport passage: hero drifts upward and rotates on departure; day opens with deeper perspective; paired text and scenes enter on opposing tracks and leave at different depths; headings settle from−24px; closing identities spread into a wider fan. Stationary frames measure the moving layers. The kinetic bridge is the focal page transition. Individual stories remain independent of scrolling: hero6.2seconds, day6.5seconds with last→first wrap; linework, identity, companion marks and creation preview repeat continuously. Remove Pause/Play stories and Replay story, hover/focus/offscreen/background stops, and terminal/manual-selection stops. Manual selection starts a full6.5second dwell then continues. Focus holds outer control frames stable while inner stories continue. OS reduced motion removes spatial effects while the illustrative content still cycles. No pinning, wheel interception, extra library or per-frame React state.

FINISH: Bounded desktop/mobile/tablet/short-height inspection, motion/pause/control checks, fresh finish reviewer, resolved verdict and design-system documentation. Existing historical plans and captures retain their earlier scope; plans/landing-visual-story.md records this revision.

Content revision: goals are one entry point into broader personal assistance. Personal trackers are verified on iPhone/iPad; general task-and-question views remain a product preview until shipped scope is confirmed. Each section adds a distinct proof rather than repeating the same promise.

Boundaries: all examples synthetic and no private APIs. Account-level privacy, shared infrastructure, external provider processing, no E2EE or independent-computer-per-assistant guarantee. Proactive experience remains in development. This request supersedes seed dfe9db78's earlier literal label exception and one-local-transition limit.
