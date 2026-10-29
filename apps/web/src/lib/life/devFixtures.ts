import type {
  MemoryFactItem,
  MemoryFactsPage,
  SemanticMemoryItem,
  SemanticMemoryPage,
  SemanticWorldGraph,
} from '../types'
import type {
  Activity,
  Attention,
  CalendarEvent,
  Commitment,
  Day,
  Decision,
  Intention,
  StateRecord,
  Task,
} from './personal'

// Small, clearly illustrative data for `?fixture=1`. Nothing here is a real person's record, and it is never part of a
// production response.

const iso = (offsetMs: number) => new Date(Date.now() + offsetMs).toISOString()
const day = (offset: number) => new Date(Date.now() + offset * 86_400_000).toISOString().slice(0, 10)
const hour = 3_600_000

const intention: Intention = {
  id: 'fixture-intention-1',
  subject: 'person',
  title: 'Run a 10k',
  kind: 'achieve',
  notes: 'Build the weekly long run.',
  ends_on: day(90),
  target: { value: 10, unit: 'km' },
  status: 'active',
  origin: 'person',
  progress: { done: 2, total: 5 },
  version: 1,
  created_at: iso(-240 * hour),
  updated_at: iso(-24 * hour),
}

const commitment: Commitment = {
  id: 'fixture-commitment-1',
  subject: 'person',
  title: 'Pay rent',
  notes: '',
  counterparty: 'landlord',
  consequence: 'Late fee',
  due_on: day(2),
  time_zone: 'UTC',
  status: 'open',
  origin: 'person',
  version: 1,
  created_at: iso(-120 * hour),
  updated_at: iso(-120 * hour),
}

const decision: Decision = {
  id: 'fixture-decision-1',
  subject: 'person',
  question: 'Track the monthly rent as a commitment?',
  kind: 'change',
  options: [
    { id: 'accept', label: 'Yes, track it' },
    { id: 'dismiss', label: 'No' },
  ],
  status: 'open',
  rationale: '',
  origin: 'agent',
  version: 1,
  created_at: iso(-12 * hour),
  updated_at: iso(-12 * hour),
}

const state: StateRecord = {
  id: 'fixture-state-1',
  subject: 'person',
  kind: 'fact',
  topic: 'running',
  predicate: 'current distance',
  value: '5 km',
  notes: 'As of this week.',
  source: 'person',
  status: 'confirmed',
  origin: 'person',
  version: 1,
  created_at: iso(-48 * hour),
  updated_at: iso(-48 * hour),
}

const activity: Activity = {
  id: 'fixture-activity-1',
  subject: 'person',
  actor: 'person',
  kind: 'occurrence',
  text: 'Easy 5k before breakfast',
  occurred_at: iso(-20 * hour),
  source: 'person',
  origin: 'person',
  created_at: iso(-20 * hour),
}

const task: Task = {
  id: 'fixture-task-1',
  subject: 'person',
  title: 'Book the dentist',
  notes: '',
  time_zone: 'UTC',
  is_priority: false,
  origin: 'person',
  version: 1,
  created_at: iso(-48 * hour),
  updated_at: iso(-48 * hour),
}

const event: CalendarEvent = {
  id: 'fixture-event-1',
  subject: 'person',
  title: 'Standup',
  notes: '',
  at: iso(2 * hour),
  minutes: 15,
  time_zone: 'UTC',
  origin: 'person',
  version: 1,
  created_at: iso(-72 * hour),
  updated_at: iso(-72 * hour),
}

const today: Day = {
  day: day(0),
  entries: [
    { task, at: iso(3 * hour), state: 'open', overdue: false },
    { event, at: iso(2 * hour), state: 'upcoming', overdue: false },
  ],
}

const attention: Attention = { commitments: [commitment], decisions: [decision], tasks: [] }

const reflection: SemanticMemoryItem = {
  id: 'fx-reflection-1',
  kind: 'mental_model',
  title: 'You do your best work in the morning',
  content: 'Across the last three weeks, the sessions you started before 10am ran twice as long as the ones after lunch.',
  created_at: iso(-21 * 86_400_000),
  updated_at: iso(-3 * 86_400_000),
  availability: 'complete',
  source_status: 'recorded',
  truncated: false,
  entities: [],
  sources: [{ id: 'fx-source-1', title: 'An older note', available: true }],
}

export function fixtureSemanticPage(
  section: 'reflections' | 'about_you',
  offset: number,
  limit: number,
): SemanticMemoryPage {
  const all = section === 'reflections' ? [reflection] : []
  return {
    schema_version: 1,
    section,
    retrieved_at: iso(0),
    bank_available: true,
    items: all.slice(offset, offset + limit),
    has_more: offset + limit < all.length,
    offset,
    limit,
  }
}

/** A small believable world, so the diagram can be looked at without a workspace (?fixture=1). */
export function fixtureSemanticWorld(): SemanticWorldGraph {
  const node = (key: string, label: string, subtype: string | undefined, attributes: Record<string, string>, mention_count: number) => ({
    id: `entity:${key}`,
    kind: 'entity',
    ...(subtype ? { subtype } : {}),
    label,
    ...(Object.keys(attributes).length ? { attributes } : {}),
    mention_count,
  })
  const edge = (from: string, label: string, to: string, source_count: number) => ({
    from: `entity:${from}`,
    to: `entity:${to}`,
    type: 'relation',
    label,
    source_count,
  })
  return {
    schema_version: 1,
    retrieved_at: iso(0),
    bank_available: true,
    nodes: [
      node('you', 'You', 'person', { role: 'founder and engineer', city: 'Lisbon' }, 42),
      node('agent-brain', 'Agent Brain', 'project', { status: 'active' }, 31),
      node('mission-control', 'Mission Control', 'project', { platform: 'iOS and web' }, 18),
      node('dana', 'Dana', 'person', { role: 'designer' }, 9),
      node('lisbon', 'Lisbon', 'place', {}, 6),
    ],
    edges: [
      edge('you', 'builds', 'agent-brain', 12),
      edge('you', 'builds', 'mission-control', 8),
      edge('you', 'lives_in', 'lisbon', 3),
      edge('dana', 'designs', 'mission-control', 4),
    ],
    truncated: false,
    limit: 100,
  }
}

export function fixtureSemanticSource(source: string): SemanticMemoryItem {
  return {
    id: source,
    kind: 'memory',
    title: 'An older note',
    content: 'The first sentence was already on the page. That seemed to be the whole trick.',
    created_at: iso(-20 * 86_400_000),
    updated_at: iso(-19 * 86_400_000),
    availability: 'complete',
    source_status: 'recorded',
    truncated: false,
    entities: [],
  }
}

const entityFacts: Record<string, MemoryFactItem[]> = {
  'fx-e-morning': [
    {
      id: 'fx-fact-1',
      text: 'Started writing before 9am on Tuesday, Wednesday and Thursday.',
      network: 'observation',
      mention_time: iso(-4 * 86_400_000),
      entities: [{ id: 'fx-e-morning', name: 'Morning routine' }],
    },
  ],
}

export function fixtureEntityFacts(entityId: string): MemoryFactsPage {
  return { bank_available: true, items: entityFacts[entityId] ?? [], has_more: false, limit: 20, offset: 0 }
}

const notification = {
  id: 'fixture-notification-1',
  source: 'life',
  kind: 'alert',
  title: 'Pay rent',
  body: 'Due in two days',
  priority: 'normal',
  link: { entity: 'commitment', id: commitment.id },
  created_at: iso(-2 * hour),
  read_at: null as string | null,
}

export async function fixtureNotificationResponse(path: string, method: string): Promise<unknown> {
  if (method === 'GET' && path.startsWith('/notifications')) {
    return { items: [notification], unread: notification.read_at ? 0 : 1, next_before: null }
  }
  if (method === 'POST' && path === '/notifications/read-all') {
    notification.read_at = iso(0)
    return { marked: 1 }
  }
  if (method === 'POST' && path.startsWith('/notifications/') && path.endsWith('/read')) {
    notification.read_at = iso(0)
    return undefined
  }
  return undefined
}

const responses: Record<string, unknown> = {
  attention_get: attention,
  day_get: today,
  intentions_list: { items: [intention], total: 1, next_offset: null },
  intentions_get: intention,
  commitments_list: { items: [commitment], total: 1, next_offset: null },
  decisions_list: { items: [decision], total: 1, next_offset: null },
  states_list: { items: [state], total: 1, next_offset: null },
  activities_list: { items: [activity], total: 1, next_offset: null },
  tasks_list: { items: [task], total: 1, next_offset: null },
  tasks_get: task,
  calendar_events_list: { items: [event], total: 1, next_offset: null },
  calendar_events_get: event,
  settings_get: { id: 'fixture-settings', time_zone: 'UTC', work_start: '09:00', work_end: '17:00', version: 1 },
}

export function fixtureLifeResponse(operation: string, _input?: Record<string, unknown>): unknown {
  return responses[operation] ?? {}
}

export function fixtureProviderResponse(provider: string, _operation: string, _input?: Record<string, unknown>): unknown {
  return { provider, series: 'body_weight', unit: 'kg', granularity: 'day', points: [] }
}
