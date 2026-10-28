/**
 * The loop shapes, ported from ~/Documents/laya-experiment/loop-designs.html and
 * condensed (2026-10-11) to match agent-harness docs/components/loop-taxonomy.md:
 * one conversation surface with three profiles, five engines, and a standing trigger.
 *
 * An engine is the one reason-act loop run under a profile as a concurrent task: prompt
 * sections, a scratchpad template, tool provisioning, budget defaults, and at most two
 * deterministic rails. Never a second runtime. Each spec below is one shape as a state
 * diagram: the trigger that starts it, the states it passes through, the condition that
 * loops it back, the evidence that exits it, and the shapes it hands off to.
 *
 * Self-loops (`from === to`) must sit on the last row: they are drawn as a bracket
 * hooked under their own node, so a row below would collide with them.
 */

/**
 * A state box is 180 wide. Its label fits about 22 characters at 12.5px and its
 * sub-label about 28 at 9.5px mono, between the padding. Longer text is silently
 * cropped by the box, so keep both under those.
 */
export type LoopNode = {
  label: string
  /** Second line, set smaller and in mono. */
  sub?: string
  /** Waiting on the world rather than working. Drawn dashed. */
  parked?: boolean
}

export type LoopSpec = {
  trigger: string
  nodes: LoopNode[]
  loop: { from: number; to: number; label: string }
  /** The evidence "done" rests on. Omitted when the shape has nothing to prove. */
  exit?: string
  handoffs?: { to: string; when: string }[]
}

export const LOOPS: Record<string, LoopSpec> = {
  // The shared skeleton every shape below is a profile of.
  anatomy: {
    trigger: 'any request',
    nodes: [
      { label: 'profile entry', sub: 'state · tools · budget' },
      { label: 'loop body', sub: 'model-steered' },
      { label: 'exit check', sub: 'evidence, not a claim' },
    ],
    loop: { from: 1, to: 1, label: 'more work needed' },
    exit: 'done · blocked · budget',
    handoffs: [{ to: '→ another shape', when: 'when the task demands it' }],
  },

  // How the surface and an engine run together: the hub's own figure.
  concurrent: {
    trigger: 'a request arrives',
    nodes: [
      { label: 'classifier proposes', sub: 'a label, validated' },
      { label: 'surface writes brief', sub: 'the model fills the slots' },
      { label: 'coordinator starts it', sub: 'revision · principal' },
      { label: 'engine works', sub: 'only its own tools' },
      { label: 'notice raised', sub: 'needs_input · done · failed' },
      { label: 'surface speaks it', sub: 'the only voice to the user' },
    ],
    loop: { from: 5, to: 3, label: 'answer returns → the engine resumes' },
    exit: 'evidence met · the user is told',
    handoffs: [{ to: '→ another engine', when: 'proposed, then validated' }],
  },

  // ── Surface profiles ─────────────────────────────────────────────────────────
  conversation: {
    trigger: 'any request',
    nodes: [
      { label: 'reason-act step' },
      { label: 'reply / small action' },
      { label: 'delegate to an engine', sub: 'start · amend · cancel' },
      { label: 'speak engine notices', sub: 'queued behind the turn' },
    ],
    loop: { from: 3, to: 0, label: 'the next message or notice' },
    exit: 'answered · blocked · budget',
    handoffs: [
      { to: '→ any engine', when: 'a task is demanded' },
      { to: '← every engine', when: 'each task ends in a notice' },
    ],
  },

  companion: {
    trigger: 'the user opens up',
    nodes: [
      { label: 'listen' },
      { label: 'reflect' },
      { label: 'one question' },
      { label: 'carry notes' },
    ],
    loop: { from: 3, to: 0, label: 'the user’s next turn' },
    // The one shape with nothing to prove, so no exit node is drawn at all.
    handoffs: [{ to: '→ transact', when: 'a real-world need surfaces' }],
  },

  learn: {
    trigger: 'session · review due',
    nodes: [
      { label: 'assess level' },
      { label: 'curriculum step' },
      { label: 'teach' },
      { label: 'exercise' },
      { label: 'feedback' },
      { label: 'schedule review', sub: 'arms a watch' },
    ],
    loop: { from: 5, to: 2, label: 'spaced review → the next session' },
    exit: 'session goal + next scheduled',
    handoffs: [
      { to: '→ produce', when: 'curriculum and exercise prep' },
      { to: '→ research', when: 'depth beyond the session' },
    ],
  },

  // ── Engines ──────────────────────────────────────────────────────────────────
  diagnose: {
    trigger: '“why is X broken?”',
    nodes: [
      { label: 'frame symptom' },
      { label: 'form hypotheses' },
      { label: 'pick investigation' },
      { label: 'collect evidence' },
      { label: 'update ledger' },
      { label: 'verify cause' },
      { label: 'report' },
    ],
    loop: { from: 4, to: 2, label: 'no cause confirmed → next investigation' },
    exit: 'verified cause · declared impasse',
    handoffs: [
      { to: '→ produce', when: 'implement the fix' },
      { to: '→ transact', when: 'run a known remedy' },
    ],
  },

  research: {
    trigger: '“look into X · decide Y”',
    nodes: [
      { label: 'scope question' },
      { label: 'broad gather' },
      { label: 'outline · coverage' },
      { label: 'gap check' },
      { label: 'drill gaps' },
      { label: 'synthesize artifact' },
    ],
    loop: { from: 4, to: 3, label: 'gaps remain' },
    exit: 'coverage met · artifact delivered',
    handoffs: [{ to: '→ transact', when: 'the user says “now do it”' }],
  },

  produce: {
    trigger: '“write · build · draft”',
    nodes: [
      { label: 'brief' },
      { label: 'draft' },
      { label: 'check vs standard' },
      { label: 'revise' },
      { label: 'deliver' },
    ],
    loop: { from: 3, to: 1, label: 'rework' },
    exit: 'check green · user accepts',
    handoffs: [{ to: '→ transact', when: 'the artifact feeds a submission' }],
  },

  transact: {
    trigger: '“book · buy · renew”',
    nodes: [
      { label: 'elicit constraints' },
      { label: 'find options · spec' },
      { label: 'evaluate vs ledger' },
      { label: 'user decides' },
      { label: 'commit', sub: 'approval' },
      { label: 'wait for them', parked: true },
      { label: 'verify attestation' },
    ],
    loop: { from: 6, to: 2, label: 'mismatch → reschedule · return · resubmit' },
    exit: 'attested by the other side · abandoned',
    handoffs: [
      { to: '← stabilize', when: 'a crisis turns out to be a task' },
      { to: '← produce', when: 'the artifact feeds a submission' },
    ],
  },

  stabilize: {
    trigger: 'urgent · deteriorating',
    nodes: [
      { label: 'triage severity' },
      { label: 'stabilize', sub: 'act first, reversibly' },
      { label: 'preserve evidence' },
      { label: 'confirm stable' },
      { label: 'follow-up' },
    ],
    loop: { from: 3, to: 1, label: 'still worsening' },
    exit: 'stopped worsening + follow-up set',
    handoffs: [
      { to: '→ diagnose', when: 'root cause' },
      { to: '→ transact', when: 'the fix' },
      { to: '→ watch', when: 'the prevention' },
    ],
  },

  // ── Standing trigger ─────────────────────────────────────────────────────────
  // A trigger starts work rather than doing it, so it offers no exit of its own: the
  // engine it launches carries the evidence.
  watch: {
    trigger: 'schedule · event fires',
    nodes: [
      { label: 'load the objective' },
      { label: 'classify it', sub: 'like any request' },
      { label: 'run the engine' },
      { label: 'record' },
      { label: 're-arm the watch' },
    ],
    loop: { from: 4, to: 0, label: 'the next wake fires' },
    handoffs: [{ to: '→ any engine', when: 'by the labeled objective' }],
  },
}
