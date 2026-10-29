import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { isLifeError, lifeRequest, newIdempotencyKey } from './client'
import type { Page, Recurrence } from './wire'

// The personal model (project-hub life-engine ADR 0010): what a person wants, owes, is deciding, knows to be true, and
// has done, plus the tasks and events that carry it out. The engine holds only asserted records; suggestions arrive as
// change-decisions and are promoted by resolving them.

export type Origin = 'person' | 'agent'
export type Target = { value: number; unit: string }

export type Intention = {
  id: string
  subject: string
  title: string
  kind: 'achieve' | 'maintain' | 'experience' | string
  notes: string
  ends_on?: string | null
  target?: Target | null
  status: 'active' | 'satisfied' | 'abandoned' | string
  origin: Origin
  derived_from?: unknown
  progress: { done: number; total: number }
  version: number
  deleted_at?: string | null
  created_at: string
  updated_at: string
}

export type Commitment = {
  id: string
  subject: string
  title: string
  notes: string
  counterparty: string
  consequence: string
  due_at?: string | null
  due_on?: string | null
  recurrence?: Recurrence | null
  alert_before_minutes?: number | null
  time_zone: string
  status: 'open' | 'met' | 'missed' | 'renegotiated' | 'waived' | string
  origin: Origin
  version: number
  deleted_at?: string | null
  created_at: string
  updated_at: string
}

export type DecisionOption = { id: string; label: string }

export type Decision = {
  id: string
  subject: string
  question: string
  kind: 'choice' | 'change' | string
  options: DecisionOption[]
  status: 'open' | 'decided' | 'deferred' | 'expired' | string
  chosen_option?: string | null
  rationale: string
  decided_by?: 'person' | 'agent' | null
  decided_at?: string | null
  expires_at?: string | null
  effect?: unknown
  origin: Origin
  derived_from?: unknown
  version: number
  created_at: string
  updated_at: string
}

export type StateRecord = {
  id: string
  subject: string
  kind: 'fact' | 'preference' | 'constraint' | 'need' | string
  topic: string
  predicate: string
  value?: unknown
  notes: string
  valid_from?: string | null
  valid_to?: string | null
  source: string
  status: 'confirmed' | 'retracted' | 'superseded' | string
  origin: Origin
  version: number
  created_at: string
  updated_at: string
}

export type Activity = {
  id: string
  subject: string
  actor: 'person' | 'agent' | 'external' | string
  kind: string
  text: string
  occurred_at: string
  source: string
  origin: Origin
  created_at: string
}

export type Task = {
  id: string
  subject: string
  title: string
  notes: string
  at?: string | null
  minutes?: number | null
  time_zone: string
  recurrence?: Recurrence | null
  alert_before_minutes?: number | null
  is_priority: boolean
  session_key?: string
  snoozed_until?: string | null
  done_at?: string | null
  result?: string
  origin: Origin
  version: number
  deleted_at?: string | null
  created_at: string
  updated_at: string
}

export type CalendarEvent = {
  id: string
  subject: string
  title: string
  notes: string
  at: string
  minutes?: number | null
  time_zone: string
  recurrence?: Recurrence | null
  alert_before_minutes?: number | null
  session_key?: string
  snoozed_until?: string | null
  cancelled_at?: string | null
  origin: Origin
  version: number
  deleted_at?: string | null
  created_at: string
  updated_at: string
}

export type Attention = {
  commitments: Commitment[]
  decisions: Decision[]
  tasks: Task[]
}

export type DayEntry = {
  task?: Task
  event?: CalendarEvent
  at: string
  state: string
  overdue: boolean
}
export type Day = { day: string; entries: DayEntry[] }

export type RecordLink = {
  from_kind: string
  from_id: string
  relation: string
  to_kind: string
  to_id: string
  created_at?: string
}

type Idempotent = { idempotency_key: string }
type Versioned = { expected_version: number }

export const personal = {
  attention: () => lifeRequest<Attention>('attention_get', {}),
  dayGet: (input: { day?: string } = {}) => lifeRequest<Day>('day_get', input),

  intentionsList: (input: { status?: string; subject?: string; search?: string; limit?: number; offset?: number } = {}) =>
    lifeRequest<Page<Intention>>('intentions_list', { limit: 100, ...input }),
  intentionsGet: (id: string) => lifeRequest<Intention>('intentions_get', { id }),
  intentionsCreate: (input: Idempotent & {
    title: string
    kind?: string
    notes?: string
    ends_on?: string | null
    target?: Target | null
    origin?: Origin
  }) => lifeRequest<Intention>('intentions_create', input),
  intentionsUpdate: (input: Idempotent & Versioned & { id: string } & Record<string, unknown>) =>
    lifeRequest<Intention>('intentions_update', input),

  commitmentsList: (input: { status?: string; subject?: string; search?: string; limit?: number; offset?: number } = {}) =>
    lifeRequest<Page<Commitment>>('commitments_list', { limit: 100, ...input }),
  commitmentsCreate: (input: Idempotent & {
    title: string
    notes?: string
    counterparty?: string
    consequence?: string
    due_at?: string | null
    due_on?: string | null
    origin?: Origin
  }) => lifeRequest<Commitment>('commitments_create', input),
  commitmentsComplete: (input: Idempotent & Versioned & { id: string; note?: string }) =>
    lifeRequest<Commitment>('commitments_complete', input),

  decisionsList: (input: { status?: string; subject?: string; search?: string; limit?: number; offset?: number } = {}) =>
    lifeRequest<Page<Decision>>('decisions_list', { limit: 100, ...input }),
  decisionsResolve: (input: Idempotent & Versioned & {
    id: string
    option: string
    rationale?: string
    decided_by?: 'person' | 'agent'
    confirmation?: { source: 'client' | 'turn'; ref: string }
  }) => lifeRequest<Decision>('decisions_resolve', input),
  decisionsDefer: (input: Idempotent & Versioned & { id: string; until?: string }) =>
    lifeRequest<Decision>('decisions_defer', input),

  statesList: (input: { kind?: string; status?: string; topic?: string; search?: string; limit?: number; offset?: number } = {}) =>
    lifeRequest<Page<StateRecord>>('states_list', { limit: 100, ...input }),
  statesCreate: (input: Idempotent & {
    kind?: string
    topic: string
    predicate: string
    value?: unknown
    notes?: string
  }) => lifeRequest<StateRecord>('states_create', input),

  activitiesList: (input: { actor?: string; kind?: string; after?: string; before?: string; search?: string; limit?: number; offset?: number } = {}) =>
    lifeRequest<Page<Activity>>('activities_list', { limit: 50, ...input }),
  activitiesRecord: (input: Idempotent & {
    actor?: string
    kind?: string
    text: string
    occurred_at: string
    source?: string
  }) => lifeRequest<Activity>('activities_record', input),

  tasksList: (input: { status?: string; subject?: string; search?: string; limit?: number; offset?: number } = {}) =>
    lifeRequest<Page<Task>>('tasks_list', { limit: 100, ...input }),
  tasksGet: (id: string) => lifeRequest<Task>('tasks_get', { id }),
  tasksComplete: (input: Idempotent & Versioned & { id: string; at?: string; done?: boolean; result?: string }) =>
    lifeRequest<Task>('tasks_complete', input),

  eventsList: (input: { status?: string; subject?: string; search?: string; limit?: number; offset?: number } = {}) =>
    lifeRequest<Page<CalendarEvent>>('calendar_events_list', { limit: 100, ...input }),

  linksSet: (input: Idempotent & {
    from_kind: string
    from_id: string
    relation: 'serves' | 'fulfils' | 'affects' | 'constrains' | 'evidences'
    to_kind: string
    to_id: string
  }) => lifeRequest<RecordLink>('links_set', input),
  linksList: (input: { kind: string; id: string; relation?: string; direction?: 'from' | 'to' | 'both' }) =>
    lifeRequest<Page<RecordLink>>('links_list', input),

  viewsState: (subject_kind: string, subject_id: string, catalog_id: string) =>
    lifeRequest<unknown>('views_state', { subject_kind, subject_id, catalog_id }),
}

export type PersonalApi = typeof personal

export const personalKeys = {
  all: ['life', 'personal'] as const,
  attention: () => [...personalKeys.all, 'attention'] as const,
  intentions: () => [...personalKeys.all, 'intentions'] as const,
  commitments: () => [...personalKeys.all, 'commitments'] as const,
  decisions: () => [...personalKeys.all, 'decisions'] as const,
  states: () => [...personalKeys.all, 'states'] as const,
  activities: () => [...personalKeys.all, 'activities'] as const,
  tasks: () => [...personalKeys.all, 'tasks'] as const,
  day: () => [...personalKeys.all, 'day'] as const,
  openTasks: () => [...personalKeys.all, 'open-tasks'] as const,
}

function retryPersonal(failureCount: number, error: unknown): boolean {
  return isLifeError(error) && error.kind === 'retry' && failureCount < 2
}

export function useAttention() {
  return useQuery({
    queryKey: personalKeys.attention(),
    queryFn: personal.attention,
    retry: retryPersonal,
    refetchInterval: 60_000,
  })
}

export function useIntentions() {
  return useQuery({
    queryKey: personalKeys.intentions(),
    queryFn: () => personal.intentionsList(),
    retry: retryPersonal,
    staleTime: 30_000,
  })
}

export function useCommitments() {
  return useQuery({
    queryKey: personalKeys.commitments(),
    queryFn: () => personal.commitmentsList({ status: 'open' }),
    retry: retryPersonal,
    staleTime: 30_000,
  })
}

export function useDecisions() {
  return useQuery({
    queryKey: personalKeys.decisions(),
    queryFn: () => personal.decisionsList({ status: 'open' }),
    retry: retryPersonal,
    staleTime: 30_000,
  })
}

export function useStates() {
  return useQuery({
    queryKey: personalKeys.states(),
    queryFn: () => personal.statesList(),
    retry: retryPersonal,
    staleTime: 60_000,
  })
}

/** Today, as the engine sees it: each occurrence of a task or event, plus open tasks still waiting from earlier days. */
export function useDay() {
  return useQuery({
    queryKey: personalKeys.day(),
    queryFn: () => personal.dayGet(),
    retry: retryPersonal,
    refetchInterval: 60_000,
  })
}

/** Open tasks, soonest first, untimed last. */
export function useOpenTasks() {
  return useQuery({
    queryKey: personalKeys.openTasks(),
    queryFn: () => personal.tasksList({ status: 'open' }),
    retry: retryPersonal,
    refetchInterval: 60_000,
  })
}

export function useActivities() {
  return useQuery({
    queryKey: personalKeys.activities(),
    queryFn: () => personal.activitiesList(),
    retry: retryPersonal,
    staleTime: 30_000,
  })
}

/** Resolve a decision. A change-decision carries its effect into the engine, which applies it atomically. */
export function useResolveDecision() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ decision, option, rationale }: { decision: Decision; option: string; rationale?: string }) =>
      personal.decisionsResolve({
        idempotency_key: newIdempotencyKey(),
        id: decision.id,
        expected_version: decision.version,
        option,
        rationale,
        confirmation: { source: 'client', ref: newIdempotencyKey() },
      }),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: personalKeys.decisions() })
      void qc.invalidateQueries({ queryKey: personalKeys.attention() })
      void qc.invalidateQueries({ queryKey: personalKeys.intentions() })
      void qc.invalidateQueries({ queryKey: personalKeys.commitments() })
    },
  })
}

export function useCompleteTask() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ task, at, done, result }: { task: Task; at?: string; done?: boolean; result?: string }) =>
      personal.tasksComplete({
        idempotency_key: newIdempotencyKey(),
        id: task.id,
        expected_version: task.version,
        at,
        done,
        result,
      }),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: personalKeys.day() })
      void qc.invalidateQueries({ queryKey: personalKeys.openTasks() })
      void qc.invalidateQueries({ queryKey: personalKeys.attention() })
      void qc.invalidateQueries({ queryKey: personalKeys.activities() })
      void qc.invalidateQueries({ queryKey: personalKeys.intentions() })
    },
  })
}

export function useCompleteCommitment() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ commitment, note }: { commitment: Commitment; note?: string }) =>
      personal.commitmentsComplete({
        idempotency_key: newIdempotencyKey(),
        id: commitment.id,
        expected_version: commitment.version,
        note,
      }),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: personalKeys.commitments() })
      void qc.invalidateQueries({ queryKey: personalKeys.attention() })
      void qc.invalidateQueries({ queryKey: personalKeys.activities() })
    },
  })
}
