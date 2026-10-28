import { lifeRequest } from './client'
import type {
  Day,
  Goal,
  Item,
  LifeSettings,
  Measurement,
  Page,
  Recurrence,
  TaskHistory,
  ViewState,
} from './wire'

type Idempotent = { idempotency_key: string }
type Versioned = { expected_version: number }

/**
 * Life Engine operation names and payloads, mirroring
 * mission-control/Core/Remote/*Service.swift. Writes always carry an
 * idempotency key; edits carry the displayed version.
 */
export const life = {
  settingsGet: () => lifeRequest<LifeSettings>('settings_get', {}),
  settingsSet: (input: Idempotent & Versioned & { time_zone: string; work_start: string; work_end: string }) =>
    lifeRequest<LifeSettings>('settings_set', input),

  dayGet: (input: { day?: string } = {}) => lifeRequest<Day>('day_get', input),
  tasksList: (input: { status?: string; limit?: number; offset?: number; goal_id?: string; after?: string; before?: string; search?: string; state?: string } = {}) =>
    lifeRequest<Page<Item>>('tasks_list', { status: 'open', limit: 200, ...input }),
  tasksGet: (id: string) => lifeRequest<Item>('tasks_get', { id }),
  tasksComplete: (input: Idempotent & Versioned & { id: string; at?: string; done?: boolean }) =>
    lifeRequest<Item>('tasks_complete', input),
  eventsList: (input: { limit?: number; offset?: number; goal_id?: string; after?: string; before?: string; search?: string; state?: string } = {}) =>
    lifeRequest<Page<Item>>('calendar_events_list', { limit: 200, ...input }),
  eventsGet: (id: string) => lifeRequest<Item>('calendar_events_get', { id }),

  tasksCreate: (input: Idempotent & {
    title: string
    notes?: string
    goal_id?: string
    at?: string | null
    minutes?: number | null
    time_zone?: string
    recurrence?: Recurrence | null
    alert_before_minutes?: number | null
    is_priority?: boolean
  }) => lifeRequest<Item>('tasks_create', input),
  tasksUpdate: (input: Idempotent & Versioned & { id: string } & Record<string, unknown>) =>
    lifeRequest<Item>('tasks_update', input),
  tasksDelete: (input: Idempotent & Versioned & { id: string }) =>
    lifeRequest<unknown>('tasks_delete', input),
  tasksSnooze: (input: Idempotent & Versioned & { id: string; until: string }) =>
    lifeRequest<Item>('tasks_snooze', input),
  tasksHistory: (id: string, days = 30) => lifeRequest<TaskHistory>('tasks_history', { id, days }),

  eventsCreate: (input: Idempotent & {
    title: string
    notes?: string
    goal_id?: string
    at: string
    minutes?: number | null
    time_zone?: string
    recurrence?: Recurrence | null
    alert_before_minutes?: number | null
  }) => lifeRequest<Item>('calendar_events_create', input),
  eventsUpdate: (input: Idempotent & Versioned & { id: string } & Record<string, unknown>) =>
    lifeRequest<Item>('calendar_events_update', input),
  eventsDelete: (input: Idempotent & Versioned & { id: string }) =>
    lifeRequest<unknown>('calendar_events_delete', input),
  eventsSnooze: (input: Idempotent & Versioned & { id: string; until: string }) =>
    lifeRequest<Item>('calendar_events_snooze', input),

  goalsList: (input: { limit?: number; offset?: number; search?: string; state?: string } = {}) =>
    lifeRequest<Page<Goal>>('goals_list', { limit: 100, ...input }),
  goalsGet: (id: string) => lifeRequest<Goal>('goals_get', { id }),
  goalsCreate: (input: Idempotent & { title: string; notes?: string; ends_on?: string | null }) =>
    lifeRequest<Goal>('goals_create', input),
  goalsUpdate: (input: Idempotent & Versioned & { id: string } & Record<string, unknown>) =>
    lifeRequest<Goal>('goals_update', input),
  goalsArchive: (input: Idempotent & Versioned & { id: string }) => lifeRequest<Goal>('goals_archive', input),
  viewsState: (subject_kind: string, subject_id: string, catalog_id: string) =>
    lifeRequest<ViewState>('views_state', { subject_kind, subject_id, catalog_id }),
  measurementRecord: (input: Idempotent & {
    subject_kind: string
    subject_id: string
    metric_id: string
    value: number
    measured_at?: string
    notes?: string | null
  }) => lifeRequest<Measurement>('measurements_record', input),
  measurementUpdate: (input: Idempotent & Versioned & {
    id: string
    value: number
    measured_at?: string
    notes?: string | null
  }) => lifeRequest<Measurement>('measurements_update', input),
  measurementDelete: (input: Idempotent & Versioned & { id: string }) =>
    lifeRequest<Measurement>('measurements_delete', input),
  trackerCatalogGet: () => lifeRequest<unknown>('tracker_catalog_get', {}),
}

export type LifeApi = typeof life
