# Implementation repository instructions

## Project mapping

- Documentation datastore: `kumarabd/project-hub`
- Project: `mission-control`
- Components implemented here: `webapp`
- Project record in the datastore: `projects/mission-control/`
- Implementation repository: `kumarabd/mission-control`
- Component source locations: `webapp: apps/webapp/`

## Project Hub is the documentation datastore

Project Hub is a shared, writable documentation datastore for projects. This repository contains implementation code; the Project Hub project record contains the requirements, architecture, specifications, decisions, concerns, implementation designs, and execution plans that implementation work reads and updates.

For this repository, use the sibling checkout at `../project-hub`. Its Mission Control record is `../project-hub/projects/mission-control/`.

At the start of every session:

1. Confirm that `../project-hub` exists and is a Git checkout whose `origin` is `https://github.com/kumarabd/project-hub.git`.
2. Inspect its branch and working tree before reading or editing it. Preserve unrelated changes; never reset or overwrite them.
3. Read and write the current files in that checkout, not a copied version in this repository. If the checkout is absent or cannot be read, stop work that depends on project documentation and report the access limitation; do not create a substitute documentation record here.

Canonical entry points in `../project-hub`:

- `projects/mission-control/README.md`
- `projects/mission-control/PRD.md`
- `projects/mission-control/architecture.md`
- `projects/mission-control/specs/project-standard.md`
- `projects/mission-control/specs/project-documentation-conventions.md`
- `projects/mission-control/implementation/README.md`
- `projects/mission-control/implementation/webapp/README.md`
- `projects/mission-control/plans/mvp.md`
- `projects/mission-control/plans/webapp/implementation.md`

The GitHub links in those documents are navigation aids. The sibling checkout is the working datastore for canonical documentation updates. Treat `projects/mission-control/` as the live project record: read it before implementation, update it when implementation changes status or decisions, and preserve its history through normal Git review. This repository must not create duplicate requirements, designs, specifications, decisions, concerns, or execution plans.

## Start or resume work

1. Read this repository's applicable instructions and inspect its current branch, changes, and implementation state.
2. Access the current Mission Control project record through the required sibling checkout described above. Do not assume another repository's instructions are automatically loaded.
3. Read the project README, PRD, architecture, implementation index, applicable component designs under `implementation/<component>/`, referenced specs and ADRs, active concerns when present, and applicable system/component plans under `plans/`.
4. Reconstruct completed work, blockers, and the next executable work package from those documents and linked implementation evidence. Do not rely on conversation memory or treat scheduled work as completed.
5. Respect unresolved definition gates. If a required decision or document is missing, report the specific gap and continue only independent work supported by accepted decisions.

## Documentation ownership

Project Hub is the canonical home and shared datastore for requirements, architecture, implementation design, shared specifications, ADRs, concerns, roadmaps, and execution plans. Update those documents in place; do not create competing copies of them in this implementation repository.

This repository owns source code, tests, build/deployment configuration, and implementation evidence. Local setup/run instructions, code comments, and generated reference documentation may live here; link to Project Hub for canonical design and planning context.

Keep component implementation details in `implementation/<component>/` in Project Hub. Keep shared behavior in `specs/`, material accepted decisions in `adr/`, and work sequencing/status in `plans/`. Preserve the system implementation index and component/repository mapping as boundaries evolve.

## Execute and checkpoint

- Implement work in the canonical plan's dependency order and run checks appropriate to the change.
- Update the canonical component plan at each completed work package and before handing off: record verified completion, implementation commit or PR links, validation results or evidence links, blockers, and the next action.
- Update affected canonical designs/specs with finalized changes. Record material architecture or behavior decisions in an ADR; do not present an unresolved proposal as accepted.
- Keep the project README/current status and system plan consistent when milestone readiness changes. Never mark work complete solely because code was written.
- Commit scoped code changes in this repository and scoped documentation changes in Project Hub. Publish through each repository's permitted branch/PR workflow; obey branch protections and task authorization. Report both revisions and any unpublished changes. A local commit alone is not a completed GitHub update.
- Preserve unrelated user changes. Fetch/check for concurrent updates before publishing; reconcile them without force-pushing over others' work.

When a canonical document needs changing, edit the corresponding file in `../project-hub`, validate it there, and commit it in the Project Hub repository. Commit implementation code and tests in this repository. Keep those revisions separate and report both.

## Access failures and handoff

Access to Project Hub must support both reading and updating canonical documents. If access or publication is blocked, state the exact blocker and pending update. Do not silently create an alternate canonical plan elsewhere or claim the docs are synchronized. Continue only independent authorized work that does not require missing context; report pending documentation changes in the handoff until access is restored.

End each handoff with completed work, verification, code/documentation revisions, outstanding blockers, and the next executable action. Future sessions must resume from committed canonical state and implementation evidence.
