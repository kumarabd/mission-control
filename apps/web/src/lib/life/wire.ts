export type Page<T> = {
  items: T[]
  total?: number
  /** The clean-slate engine's cursor: the offset of the next page, or null at the end. */
  next_offset?: number | null
  /** The retired contract's page fields. */
  limit?: number
  offset?: number
  has_more?: boolean
}

export type PlanItem = {
  id: string
  day: string
  title: string
  kind: 'task' | 'event' | string
  minutes: number
  is_priority: boolean
  start_at?: string | null
  done_at?: string | null
  goal_id?: string | null
  step_id?: string | null
  version: number
  created_at?: string
  updated_at?: string
  deleted_at?: string | null
}

export type PlanSummary = {
  planned: number
  done: number
  minutes_open: number
  minutes_done: number
  minutes_events: number
}

export type Plan = {
  day: string
  items: PlanItem[]
  proposals?: unknown[]
  summary: PlanSummary
}

export type NextSuggestion = {
  title: string
  minutes: number
  reason: string
  source: 'plan_item' | 'goal_step' | string
  plan_item_id?: string | null
  goal_id?: string | null
  step_id?: string | null
}

export type NextAction = { suggestion: NextSuggestion | null }

export type Nudge = { at: string; message?: string | null }

export type Routine = {
  id: string
  title: string
  minutes: number
  short_title?: string | null
  short_minutes?: number | null
  weekdays: number[]
  target_per_day: number
  nudges?: Nudge[]
  time_zone?: string
  version: number
  created_at?: string
  updated_at?: string
  deleted_at?: string | null
}

export type RoutineStatus = {
  routine: Routine
  scheduled: boolean
  target: number
  count: number
  done: boolean
  variant?: 'full' | 'short' | string | null
  streak: number
  days_since_last?: number | null
  gap: boolean
  hint?: string | null
}

export type RoutineHistoryDay = {
  day: string
  scheduled: boolean
  count: number
  target: number
  done: boolean
}

export type RoutineHistory = {
  routine: Routine
  days: RoutineHistoryDay[]
  last_7: { done: number; scheduled: number }
  last_30: { done: number; scheduled: number }
  streak: number
  best_streak: number
}

export type Recurrence = {
  freq: 'daily' | 'weekly' | 'monthly' | string
  interval?: number
  weekdays?: number[]
}

export type Reminder = {
  id: string
  title: string
  notes?: string | null
  due_at?: string | null
  snoozed_until?: string | null
  time_zone: string
  recurrence?: Recurrence | null
  source?: string
  session_id?: string | null
  turn_seq?: number | null
  link?: { entity?: string; id?: string } | string | null
  state: 'pending' | 'done'
  completed_at?: string | null
  last_completed_at?: string | null
  version: number
  deleted_at?: string | null
  created_at?: string
  updated_at?: string
}

export type AgendaItem = {
  reminder: Reminder
  at?: string | null
  state: 'upcoming' | 'due' | 'acknowledged' | string
  overdue: boolean
}

export type ReminderAgenda = { day: string; items: AgendaItem[] }

export type Step = {
  id: string
  goal_id: string
  title: string
  minutes: number
  position: number
  done_at?: string | null
  version: number
}

export type Consistency = { done: number; scheduled: number }

export type GoalConsistency = {
  last_7: Consistency
  last_30: Consistency
}

/**
 * A task or an event: one record told apart by `kind`. A task waits for someone to do it (a time is a deadline or a
 * cue); an event happens at its time. Either may repeat and either may alert — a reminder is an alert, a routine is a
 * task that repeats. This is the clean-slate Life Engine's shape, which has no separate steps or routines.
 */
export type Item = {
  id: string
  kind: 'task' | 'event' | string
  subject?: string
  title: string
  notes?: string
  goal_id?: string | null
  at?: string | null
  minutes?: number | null
  time_zone?: string
  recurrence?: Recurrence | null
  alert_before_minutes?: number | null
  is_priority?: boolean
  snoozed_until?: string | null
  done_at?: string | null
  version: number
  deleted_at?: string | null
  created_at?: string
  updated_at?: string
}

/** One occurrence of a task or event on a day; a repeating item appears once for each time it falls. */
export type DayEntry = {
  item: Item
  at: string
  state: 'open' | 'done' | 'upcoming' | 'past' | string
  overdue?: boolean
}

export type Day = { day: string; entries: DayEntry[] }

export type Goal = {
  id: string
  subject?: string
  title: string
  notes?: string | null
  ends_on?: string | null
  version: number
  progress: { done: number; total: number }
  /** The linked open task that comes first, or null. */
  next?: Item | null
  deleted_at?: string | null
  created_at?: string
  updated_at?: string
  /** Legacy fields from the pre-clean-slate engine; absent from current responses, so never assume them. */
  why?: string | null
  weekly_target?: number | null
  archived_at?: string | null
  steps?: Step[]
  next_step?: Step | null
  routine_ids?: string[]
  consistency?: GoalConsistency | null
}

export type TrackerMetric = {
  id: string
  label: string
  unit: string
  target?: number | null
  minimum?: number | null
  maximum?: number | null
}

/** Where a metric's values come from: a data provider's series, read live. */
export type MetricSource = {
  /** The provider's router prefix, for example `finance`. */
  provider: string
  series: string
  /** day, week or month: the resolution asked of the provider. Omitted means day. */
  granularity?: string | null
}

/**
 * A metric is a data source a view's blocks draw: a provider series (`source`), a repeating task's done occurrences
 * (`task_id`; `routine_id` on the retired contract), or numbers the person logs themselves (neither).
 */
export type ViewMetric = TrackerMetric & {
  source?: MetricSource | null
  task_id?: string | null
  routine_id?: string | null
}

/** A repeating task's recent days, for a metric that reads its done occurrences. */
export type TaskHistoryDay = { day: string; scheduled: boolean; count: number; target: number; done: boolean }
export type TaskHistory = {
  task: Item
  days: TaskHistoryDay[]
  last7: { done: number; scheduled: number }
  last30: { done: number; scheduled: number }
  streak: number
  best_streak: number
}

/**
 * The view kit. A view is composed from a finite set of blocks and calculations; none of it names a kind of goal.
 * The engine validates a manifest and this client evaluates the calculations on live data, so no figure in a view was
 * written by the model (the engine's tracker_catalog_get documents the kit).
 */
export type KitWindow = { period?: string | null; days?: number | null }
export type Calc = {
  fn: string
  metric?: string | null
  value?: number | null
  date?: string | null
  window?: KitWindow | null
  period?: string | null
  per?: string | null
  args?: Calc[] | null
}
export type Slot = { calc: Calc; format: string; unit?: string | null; decimals?: number | null }
export type Marker = { at: Calc; label: string }
export type Band = { from: Calc; to: Calc; label: string }

/** One block of a view, a flat shape: which fields a kind uses is the engine's catalogue. */
export type ViewBlock = {
  id: string
  /** sentence | bar | series | grid | steps | timeline | log | text | link. A client shows an unknown kind as unsupported. */
  kind: string
  title?: string | null
  emphasis?: string | null
  text?: string | null
  slots?: Record<string, Slot> | null
  value?: Calc | null
  of?: Calc | null
  markers?: Marker[] | null
  projection?: Calc | null
  metric?: string | null
  style?: string | null
  window?: KitWindow | null
  bucket?: string | null
  aggregate?: string | null
  lines?: Marker[] | null
  band?: Band | null
  trend_to?: Calc | null
  layout?: string | null
  weeks?: number | null
  source?: string | null
  thresholds?: number[] | null
  format?: string | null
  unit?: string | null
  decimals?: number | null
  body?: string | null
  points?: string[] | null
  url?: string | null
}

/** A view is pages of titled sections of blocks. The structure is the engine's; what fills it is the composer's. */
export type ViewSection = { id: string; title: string; intro?: string | null; blocks: ViewBlock[] }
export type ViewPage = { id: string; title?: string | null; sections: ViewSection[] }

/** A goal's tracker for one client catalogue: a manifest of blocks that refer to the goal and to metrics. */
export type GoalView = {
  id: string
  subject_kind: string
  subject_id: string
  catalog_id: string
  metrics: ViewMetric[]
  pages: ViewPage[]
  version: number
  created_at?: string
  updated_at?: string
}

export type Measurement = {
  id: string
  subject_kind?: string
  subject_id?: string
  /** Retired contract: measurements now hang off a goal, task or event by subject. */
  goal_id?: string
  metric_id: string
  unit?: string
  value: number
  measured_at: string
  notes?: string | null
  version: number
  deleted_at?: string | null
  created_at?: string
  updated_at?: string
}

export type ViewState = {
  subject_kind?: string
  subject_id?: string
  /** Retired contract. */
  goal_id?: string
  catalog_id: string
  view: GoalView | null
  measurements: Measurement[]
}

export type SeriesPoint = { t: string; value: number }

export type SeriesData = {
  provider: string
  series: string
  unit: string
  granularity: string
  /** Only periods that have records, oldest first. A missing period is a gap, not zero. */
  points: SeriesPoint[]
}

export type LifeSettings = {
  id: string
  time_zone: string
  work_start: string
  work_end: string
  version: number
}

export type LifeErrorKind =
  | 'unauthorized'
  | 'not_provisioned'
  | 'not_found'
  | 'conflict'
  | 'retry'
  | 'invalid_input'
  | 'duplicate'
  | 'too_large'
  | 'busy'
  | 'engine'
  | 'server'
  | 'invalid_response'

export type LifeErrorEnvelope = {
  error?: { code?: string; message?: string } | string
  message?: string
}
