import {
  Archive,
  Bell,
  Brain,
  GitBranch,
  Inbox,
  Lock,
  type LucideIcon,
  MessagesSquare,
  Network,
  Route,
  ShieldCheck,
  Sparkles,
} from 'lucide-react'
import type { LoopSpec } from './loops'

/**
 * The picture that carries each doc before the prose does.
 *
 * One diagram per page, keyed by slug, rendered above the article body. Two things
 * are being drawn here, and they are different kinds of thing:
 *
 *   `machine`  a process. Drawn in the state-diagram notation ported from the
 *              loop-designs benchmark: trigger, states, parked nodes, a labelled
 *              loop-back edge, and the exit that evidence opens. This is used
 *              wherever the subject is a sequence of steps.
 *   `regions`  a structure. Containment or opposition, which has no sequence and
 *              no exit, so the notation above would say nothing true about it.
 *
 * Every label is readable with the animation switched off, so the page still
 * teaches in reduced motion, in print, and to a screen reader. Labels are plain
 * words: a diagram that needs the prose to be legible has failed at its one job.
 */

export type DiagramSide = {
  title: string
  icon: LucideIcon
  items: string[]
  tone?: 'plain' | 'accent'
}

export type Diagram =
  /** A process, in the drafting-sheet notation. */
  | { shape: 'machine'; caption: string; mark: LucideIcon; spec: LoopSpec }
  /** Two regions, `nested` puts the first inside a named boundary and the second outside it. */
  | { shape: 'regions'; caption: string; sides: DiagramSide[]; nested?: boolean; boundary?: string }

/**
 * The glyph a page is recognised by, reused by the related-pages chips so a
 * cross-reference carries the same mark the reader just saw on the figure.
 */
export function signatureIcon(diagram: Diagram): LucideIcon {
  return diagram.shape === 'machine' ? diagram.mark : diagram.sides[0].icon
}

export const DIAGRAMS: Record<string, Diagram> = {
  'concepts/the-agent': {
    shape: 'machine',
    mark: Brain,
    caption:
      'One cycle, repeated until the task is finished. The orchestrator owns the loop; the model only supplies the reasoning inside it.',
    spec: {
      trigger: 'a request',
      nodes: [
        { label: 'Reason', sub: 'read the state, pick a move' },
        { label: 'Act', sub: 'a tool or a question' },
        { label: 'Observe', sub: 'the result returns' },
      ],
      loop: { from: 2, to: 0, label: 'the result feeds the next round' },
      exit: 'done · blocked · budget',
      handoffs: [{ to: '→ every other shape', when: 'they are all profiles of this one' }],
    },
  },

  'concepts/turns': {
    shape: 'machine',
    mark: Inbox,
    caption: 'One turn, from your message arriving to the answer coming back.',
    spec: {
      trigger: 'a message arrives',
      nodes: [
        { label: 'Accept', sub: 'attach to a session' },
        { label: 'Assemble', sub: 'context and memory' },
        { label: 'Loop', sub: 'reason · act · observe' },
        { label: 'Close', sub: 'deliver, then write memory' },
      ],
      loop: { from: 2, to: 2, label: 'until it stops' },
      exit: 'delivered · written to memory',
      handoffs: [{ to: '→ memory', when: 'at close, into long-term storage' }],
    },
  },

  'concepts/memory': {
    shape: 'regions',
    caption:
      'Two stores with different lifetimes. A session forgets by design; memory is what it deliberately carries forward.',
    sides: [
      {
        title: 'Within a session',
        icon: MessagesSquare,
        items: ['Ordinary conversation', 'Compacted as it grows', 'Older material shed first', 'Gone when the session ends'],
      },
      {
        title: 'Across sessions',
        icon: Archive,
        tone: 'accent',
        items: ['Written at the end of a turn', 'Read by the model, on its own call', 'Scoped to your account alone', 'What the next session starts from'],
      },
    ],
  },

  'concepts/approvals': {
    shape: 'machine',
    mark: ShieldCheck,
    caption: 'The gate sits on the action itself, not on a category of actions.',
    spec: {
      trigger: 'the turn reaches a gated action',
      nodes: [
        { label: 'Suspends', sub: 'nothing is sent', parked: true },
        { label: 'You see the exact call', sub: 'the real arguments' },
        { label: 'Decision recorded', sub: 'approved or denied' },
        { label: 'The turn resumes', sub: 'with the outcome' },
      ],
      loop: { from: 0, to: 0, label: 'waits for you' },
      exit: 'approved · denied · both logged',
      handoffs: [{ to: '→ activity', when: 'every decision is audited' }],
    },
  },

  'concepts/proactivity': {
    shape: 'machine',
    mark: Bell,
    caption: 'A wake that finds nothing ends quietly. Nothing is invented to justify having run.',
    spec: {
      trigger: 'a scheduled wake fires',
      nodes: [
        { label: 'Run a full turn', sub: 'budget · tools · logged' },
        { label: 'Judge: worth telling?', sub: 'the selection rule' },
        { label: 'Told, with reasoning', sub: 'you hear about it' },
        { label: 'Or logged quiet', sub: 'a real outcome, recorded' },
      ],
      loop: { from: 3, to: 0, label: 'the next wake' },
      exit: 'told · or quiet, both logged',
      handoffs: [{ to: '→ activity', when: 'wakes appear beside your own turns' }],
    },
  },

  'architecture/topology': {
    shape: 'machine',
    mark: Route,
    caption: 'Each stage exists because something had to be pulled out of the stage before it.',
    spec: {
      trigger: 'a message from a device',
      nodes: [
        { label: 'Your device', sub: 'web · phone · watch · car' },
        { label: 'Identity', sub: 'router · gateway' },
        { label: 'The work', sub: 'coordinator · workers' },
        { label: 'State', sub: 'postgres · memory' },
        { label: 'Answer', sub: 'to your channel' },
      ],
      loop: { from: 2, to: 2, label: 'the turn loop' },
      exit: 'delivered on the channel you used',
      handoffs: [
        { to: '→ isolation', when: 'every stage above is scoped to you' },
        { to: '→ delegation', when: 'the turn hands work to a child' },
      ],
    },
  },

  'architecture/isolation': {
    shape: 'regions',
    nested: true,
    boundary: 'Your boundary',
    caption:
      'The boundary is deployment topology, not a check the code has to remember. A separate database cannot forget a WHERE clause.',
    sides: [
      {
        title: 'Dedicated to you',
        icon: Lock,
        tone: 'accent',
        items: ['A Kubernetes namespace', 'Its own Postgres instance', 'Its own volume for session files', 'Your credentials, in your worker fleet'],
      },
      {
        title: 'Shared, and safe to be',
        icon: Network,
        items: ['The reasoning loop that sequences work', 'Holds identifiers, never content', 'Safe by a reference-passing contract', 'One accepted cost: blast radius'],
      },
    ],
  },

  'architecture/delegation': {
    shape: 'machine',
    mark: GitBranch,
    caption: 'The parent keeps its own context and gets back a result, not a log.',
    spec: {
      trigger: 'the parent names a scope',
      nodes: [
        { label: 'A child runs', sub: 'own workspace · own budget' },
        { label: 'The parent waits', sub: 'its context untouched', parked: true },
        { label: 'A summary returns', sub: 'not the raw stream' },
        { label: 'The parent weighs it', sub: 'an observation to judge' },
      ],
      loop: { from: 1, to: 1, label: 'waiting on the child' },
      exit: 'a summary, not a log',
      handoffs: [{ to: '→ turns', when: 'the parent turn resumes' }],
    },
  },

  'guides/getting-started': {
    shape: 'machine',
    mark: Sparkles,
    caption: 'A fresh account to an assistant that knows something, in five moves.',
    spec: {
      trigger: 'a fresh account',
      nodes: [
        { label: 'Ask something real', sub: 'not a greeting' },
        { label: 'Say what to remember', sub: 'once, in conversation' },
        { label: 'Connect one thing', sub: 'one you understand' },
        { label: 'Review what it did', sub: 'every turn is recorded' },
        { label: 'Set the boundary', sub: 'what needs sign-off' },
      ],
      loop: { from: 0, to: 0, label: 'each session' },
      exit: 'an assistant that knows something',
      handoffs: [{ to: '→ the agent', when: 'what is actually running' }],
    },
  },
}

/** The docs index leads with the whole picture, not with a table of contents. */
export const INDEX_DIAGRAM: Diagram = {
  shape: 'machine',
  mark: Brain,
  caption: 'The short version of everything in these pages.',
  spec: {
    trigger: 'you ask',
    nodes: [
      { label: 'The agent works', sub: 'a durable loop' },
      { label: 'It remembers', sub: 'memory you own' },
      { label: 'You decide', sub: 'anything consequential' },
    ],
    loop: { from: 2, to: 0, label: 'and around again' },
    exit: 'a result you can check',
  },
}
