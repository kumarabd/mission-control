import { addDays, localDay, parseDay, resolvedTimeZone } from './time'
import type {
  MemoryFactItem,
  MemoryFactsPage,
  SemanticMemoryItem,
  SemanticMemoryPage,
  SemanticWorldGraph,
} from '../types'
import type {
  AgendaItem,
  Day,
  DayEntry,
  Goal,
  Item,
  LifeSettings,
  Measurement,
  NextAction,
  Page,
  Plan,
  PlanItem,
  Reminder,
  ReminderAgenda,
  Routine,
  RoutineHistory,
  RoutineStatus,
  Step,
  TaskHistory,
  GoalView,
  ViewBlock,
  ViewPage,
  SeriesData,
  ViewMetric,
  ViewState,
} from './wire'

/**
 * DEV-only fixture data for visual QA. It mirrors the native DevData shapes,
 * only loads when `?fixture=1` was opened (see devFixture.ts), and is never
 * part of a production bundle.
 */

const DAY = localDay()
const ZONE = resolvedTimeZone()

const iso = (offsetMs: number) => new Date(Date.now() + offsetMs).toISOString()
const minutesFromNow = (minutes: number) => iso(minutes * 60_000)

function planItem(input: Partial<PlanItem> & Pick<PlanItem, 'id' | 'title'>): PlanItem {
  return {
    day: DAY,
    kind: 'task',
    minutes: 25,
    is_priority: false,
    start_at: null,
    done_at: null,
    goal_id: null,
    step_id: null,
    version: 1,
    created_at: iso(-86_400_000),
    updated_at: iso(-3_600_000),
    ...input,
  }
}

// The weight is bound to a provider's series (read live, see fixtureProviderResponse); the pages are logged by hand.
const metrics: ViewMetric[] = [
  { id: 'fx-m-weight', label: 'Weight', unit: 'kg', target: 70, minimum: 40, maximum: 150, source: { provider: 'health', series: 'body_weight' } },
  { id: 'fx-m-pages', label: 'Pages read', unit: 'pages', target: 500, minimum: 0, maximum: 2000 },
  { id: 'fx-m-read-days', label: 'Reading days', unit: 'times', task_id: 'fx-task-read' },
]

const blocks: ViewBlock[] = [
  { id: 'fx-s0', kind: 'sentence', emphasis: 'hero', text: '{down} down, {togo} to go',
    slots: {
      down: { calc: { fn: 'sub', args: [{ fn: 'first', metric: 'fx-m-weight' }, { fn: 'latest', metric: 'fx-m-weight' }] }, format: 'number', unit: 'kg', decimals: 1 },
      togo: { calc: { fn: 'sub', args: [{ fn: 'latest', metric: 'fx-m-weight' }, { fn: 'const', value: 70 }] }, format: 'number', unit: 'kg', decimals: 1 },
    } },
  { id: 'fx-s1', kind: 'series', title: 'Weight trend', metric: 'fx-m-weight', style: 'line', window: { days: 60 },
    band: { from: { fn: 'const', value: 69.5 }, to: { fn: 'const', value: 70.5 }, label: 'target' }, trend_to: { fn: 'const', value: 70 }, unit: 'kg' },
  { id: 'fx-s1b', kind: 'bar', title: 'Pages so far', value: { fn: 'sum', metric: 'fx-m-pages' }, of: { fn: 'const', value: 500 },
    markers: [{ at: { fn: 'const', value: 250 }, label: 'halfway' }], format: 'number', unit: 'pages' },
  { id: 'fx-s1c', kind: 'grid', title: 'Reading days', metric: 'fx-m-read-days', layout: 'month_grid', weeks: 5 },
  { id: 'fx-s1d', kind: 'tasks', title: 'Tasks that serve it' },
  { id: 'fx-s1e', kind: 'events', title: 'Events that serve it' },
  { id: 'fx-s2', kind: 'log', title: 'Reading check-in', metric: 'fx-m-pages' },
  { id: 'fx-s3', kind: 'steps', title: 'Milestones', source: 'goal_steps' },
  { id: 'fx-s4', kind: 'text', body: 'A little every day beats a lot on Sunday.', points: ['Same time, same chair', 'Stop when the timer rings'] },
  { id: 'fx-s5', kind: 'link', title: 'The reading plan', url: 'https://example.com/reading-plan' },
]

const pages: ViewPage[] = [
  { id: 'fx-p-progress', title: 'Progress', sections: [
    { id: 'fx-sec-now', title: 'Where it stands', intro: 'Weight is the thing being changed; pages are how the book gets written.', blocks: blocks.slice(0, 3) },
    { id: 'fx-sec-habit', title: 'The reading habit', intro: 'Every filled cell is a day you read.', blocks: blocks.slice(3, 7) },
  ] },
  { id: 'fx-p-plan', title: 'Plan', sections: [
    { id: 'fx-sec-steps', title: 'Milestones', blocks: blocks.slice(7, 8) },
    { id: 'fx-sec-notes', title: 'Why and how', blocks: blocks.slice(8) },
  ] },
]

function viewFor(catalogId: string): GoalView {
  return {
    id: 'fx-view-book',
    subject_kind: 'goal',
    subject_id: 'fx-goal-book',
    catalog_id: catalogId,
    metrics,
    pages,
    version: 1,
  }
}

const measurements: Measurement[] = [
  { id: 'fx-m1', goal_id: 'fx-goal-book', metric_id: 'fx-m-weight', unit: 'kg', value: 78.4, measured_at: iso(-20 * 86_400_000), notes: '', version: 1 },
  { id: 'fx-m2', goal_id: 'fx-goal-book', metric_id: 'fx-m-weight', unit: 'kg', value: 78.1, measured_at: iso(-15 * 86_400_000), notes: '', version: 1 },
  { id: 'fx-m3', goal_id: 'fx-goal-book', metric_id: 'fx-m-weight', unit: 'kg', value: 77.8, measured_at: iso(-11 * 86_400_000), notes: 'After the morning walk', version: 1 },
  { id: 'fx-m4', goal_id: 'fx-goal-book', metric_id: 'fx-m-weight', unit: 'kg', value: 77.9, measured_at: iso(-7 * 86_400_000), notes: '', version: 1 },
  { id: 'fx-m5', goal_id: 'fx-goal-book', metric_id: 'fx-m-weight', unit: 'kg', value: 77.4, measured_at: iso(-3 * 86_400_000), notes: '', version: 1 },
  { id: 'fx-m6', goal_id: 'fx-goal-book', metric_id: 'fx-m-weight', unit: 'kg', value: 77.2, measured_at: iso(-86_400_000), notes: '', version: 1 },
  { id: 'fx-p1', goal_id: 'fx-goal-book', metric_id: 'fx-m-pages', unit: 'pages', value: 24, measured_at: iso(-2 * 86_400_000), notes: 'Two chapters on the train', version: 1 },
  { id: 'fx-p2', goal_id: 'fx-goal-book', metric_id: 'fx-m-pages', unit: 'pages', value: 38, measured_at: iso(-86_400_000), notes: '', version: 1 },
]

const step1: Step = { id: 'fx-step-1', goal_id: 'fx-goal-book', title: 'Choose the through-line', minutes: 30, position: 1, done_at: iso(-12 * 86_400_000), version: 2 }
const step2: Step = { id: 'fx-step-2', goal_id: 'fx-goal-book', title: 'Outline the first chapter', minutes: 25, position: 2, done_at: null, version: 1 }
const step3: Step = { id: 'fx-step-3', goal_id: 'fx-goal-book', title: 'Write 1,000 words', minutes: 45, position: 3, done_at: null, version: 1 }

const goals: Goal[] = [
  {
    id: 'fx-goal-book',
    title: 'Write the book',
    why: 'Finish the first draft by the end of the year.',
    weekly_target: 5,
    version: 3,
    steps: [step1, step2, step3],
    progress: { done: 1, total: 3 },
    next_step: step2,
    routine_ids: ['fx-routine-read'],
    consistency: { last_7: { done: 4, scheduled: 5 }, last_30: { done: 18, scheduled: 24 } },
    created_at: iso(-30 * 86_400_000),
    updated_at: iso(-86_400_000),
  },
  {
    id: 'fx-goal-fitter',
    title: 'Get fitter',
    why: 'Feel stronger on the hills this winter.',
    weekly_target: 3,
    version: 2,
    steps: [
      { id: 'fx-step-4', goal_id: 'fx-goal-fitter', title: 'Book a baseline check', minutes: 20, position: 1, done_at: null, version: 1 },
      { id: 'fx-step-5', goal_id: 'fx-goal-fitter', title: 'Plan three walks a week', minutes: 15, position: 2, done_at: null, version: 1 },
    ],
    progress: { done: 0, total: 2 },
    next_step: { id: 'fx-step-4', goal_id: 'fx-goal-fitter', title: 'Book a baseline check', minutes: 20, position: 1, done_at: null, version: 1 },
    routine_ids: ['fx-routine-walk'],
    consistency: { last_7: { done: 2, scheduled: 3 }, last_30: { done: 8, scheduled: 12 } },
    created_at: iso(-20 * 86_400_000),
    updated_at: iso(-2 * 86_400_000),
  },
]

function routine(input: {
  id: string
  title: string
  minutes: number
  shortTitle?: string
  shortMinutes?: number
  weekdays?: number[]
  target?: number
  nudges?: { at: string; message?: string | null }[]
}): Routine {
  return {
    id: input.id,
    title: input.title,
    minutes: input.minutes,
    short_title: input.shortTitle ?? null,
    short_minutes: input.shortMinutes ?? null,
    weekdays: input.weekdays ?? [],
    target_per_day: input.target ?? 1,
    nudges: input.nudges ?? [{ at: '09:00', message: null }],
    time_zone: ZONE,
    version: 1,
    created_at: iso(-30 * 86_400_000),
    updated_at: iso(-86_400_000),
    deleted_at: null,
  }
}

function status(
  routineValue: Routine,
  input: { scheduled: boolean; count: number; target?: number; done?: boolean; hint?: string; gap?: boolean; variant?: 'full' | 'short' },
): RoutineStatus {
  const target = input.target ?? routineValue.target_per_day
  return {
    routine: routineValue,
    scheduled: input.scheduled,
    target,
    count: input.count,
    done: input.done ?? input.count >= target,
    variant: input.variant ?? null,
    streak: 4,
    days_since_last: 0,
    gap: input.gap ?? false,
    hint: input.hint ?? null,
  }
}

const routineStatuses: RoutineStatus[] = [
  status(routine({ id: 'fx-routine-water', title: 'Drink water', minutes: 1, target: 3, shortTitle: 'One glass', shortMinutes: 1, nudges: [{ at: '09:30', message: 'Start the day with a glass' }, { at: '13:00', message: null }, { at: '17:00', message: null }] }), {
    scheduled: true,
    count: 1,
    hint: 'One more glass reaches today’s target.',
  }),
  status(routine({ id: 'fx-routine-read', title: 'Read 20 minutes', minutes: 20, shortTitle: 'Read one page', shortMinutes: 2, nudges: [{ at: '20:30', message: 'Before bed' }] }), {
    scheduled: true,
    count: 0,
    hint: 'No reading yet today.',
  }),
  status(routine({ id: 'fx-routine-walk', title: 'Walk after lunch', minutes: 15, shortTitle: 'Walk to the corner', shortMinutes: 5 }), {
    scheduled: true,
    count: 1,
    hint: 'Done for today.',
  }),
  status(routine({ id: 'fx-routine-journal', title: 'Evening journal', minutes: 10, weekdays: [1, 3, 5] }), {
    scheduled: false,
    count: 0,
  }),
]

function historyFor(item: RoutineStatus): RoutineHistory {
  const days = Array.from({ length: 30 }, (_, index) => addDays(DAY, index - 29))
  const rows = days.map((day, index) => {
    const weekday = parseDay(day).getDay()
    const scheduled =
      item.routine.weekdays.length === 0 || item.routine.weekdays.includes(weekday)
    let count = 0
    if (scheduled) {
      count = index % 5 === 0 ? 0 : index % 3 === 0 ? Math.max(1, item.target - 1) : item.target
    }
    if (day === DAY) count = item.count
    return {
      day,
      scheduled,
      count,
      target: item.target,
      done: scheduled && count >= item.target,
    }
  })
  const totals = (slice: typeof rows) => {
    const scheduled = slice.filter((row) => row.scheduled)
    return {
      done: scheduled.filter((row) => row.done).length,
      scheduled: scheduled.length,
    }
  }
  let streak = 0
  for (let index = rows.length - 1; index >= 0; index -= 1) {
    const row = rows[index]
    if (!row.scheduled) continue
    if (!row.done) break
    streak += 1
  }
  let best = 0
  let run = 0
  for (const row of rows) {
    if (!row.scheduled) continue
    run = row.done ? run + 1 : 0
    best = Math.max(best, run)
  }
  return {
    routine: item.routine,
    days: rows,
    last_7: totals(rows.slice(-7)),
    last_30: totals(rows),
    streak,
    best_streak: Math.max(best, streak),
  }
}

const planItems: PlanItem[] = [
  planItem({ id: 'fx-task-read', title: 'Read 20 minutes', minutes: 20, goal_id: 'fx-goal-book', start_at: minutesFromNow(-120), done_at: iso(-60_000) }),
  planItem({ id: 'fx-event-standup', title: 'Team standup', kind: 'event', minutes: 15, start_at: minutesFromNow(-90) }),
  planItem({ id: 'fx-task-deep', title: 'Deep work: first chapter', minutes: 90, is_priority: true, start_at: minutesFromNow(-30), goal_id: 'fx-goal-book', step_id: 'fx-step-2' }),
  planItem({ id: 'fx-task-errand', title: 'Pick up the dry cleaning', minutes: 25, start_at: minutesFromNow(75) }),
  planItem({ id: 'fx-event-dinner', title: 'Dinner with Priya', kind: 'event', minutes: 90, start_at: minutesFromNow(240) }),
  planItem({ id: 'fx-task-launch', title: 'Draft the launch note', minutes: 45, is_priority: true }),
  planItem({ id: 'fx-task-reply', title: 'Reply to Priya about the trip', minutes: 15 }),
  planItem({ id: 'fx-task-dentist', title: 'Book the dentist', minutes: 10, goal_id: 'fx-goal-fitter' }),
  planItem({ id: 'fx-task-stretch', title: 'Morning stretch', minutes: 10, done_at: iso(-3 * 3_600_000) }),
]

const reminders: Reminder[] = [
  {
    id: 'fx-rem-call',
    title: 'Call Sam',
    notes: 'Ask about the weekend plans and the car.',
    due_at: minutesFromNow(-60),
    snoozed_until: null,
    time_zone: ZONE,
    recurrence: null,
    source: 'agent',
    state: 'pending',
    version: 1,
    created_at: iso(-4 * 3_600_000),
    updated_at: iso(-3_600_000),
  },
  {
    id: 'fx-rem-rent',
    title: 'Pay rent',
    notes: null,
    due_at: iso(2 * 86_400_000),
    snoozed_until: null,
    time_zone: ZONE,
    recurrence: { freq: 'monthly', interval: 1 },
    source: 'user',
    state: 'pending',
    version: 2,
    created_at: iso(-20 * 86_400_000),
    updated_at: iso(-2 * 86_400_000),
  },
  {
    id: 'fx-rem-passport',
    title: 'Renew passport',
    link: { entity: 'goal', id: 'fx-goal-book' },
    notes: 'The form is in the desk drawer.',
    due_at: null,
    snoozed_until: null,
    time_zone: ZONE,
    recurrence: null,
    source: 'user',
    state: 'pending',
    version: 1,
    created_at: iso(-5 * 86_400_000),
    updated_at: iso(-5 * 86_400_000),
  },
  {
    id: 'fx-rem-invoice',
    title: 'Send the invoice',
    notes: null,
    due_at: iso(-5 * 3_600_000),
    time_zone: ZONE,
    recurrence: null,
    source: 'user',
    state: 'done',
    completed_at: iso(-2 * 3_600_000),
    version: 3,
    created_at: iso(-2 * 86_400_000),
    updated_at: iso(-2 * 3_600_000),
  },
]

const settings: LifeSettings = {
  id: 'fx-settings',
  time_zone: ZONE,
  work_start: '09:00',
  work_end: '17:30',
  version: 1,
}

const notifications = [
  {
    id: 'fx-notif-1',
    source: 'life',
    kind: 'reminder',
    title: 'Call Sam',
    body: 'It’s time for the reminder you set.',
    priority: 'normal',
    link: { entity: 'reminder', id: 'fx-rem-call' },
    session_id: null,
    created_at: iso(-40 * 60_000),
    read_at: null,
  },
  {
    id: 'fx-notif-2',
    source: 'life',
    kind: 'routine',
    title: 'Read 20 minutes',
    body: 'You haven’t read yet today. A short version counts.',
    priority: 'normal',
    link: { entity: 'routine', id: 'fx-routine-read' },
    session_id: null,
    created_at: iso(-3 * 3_600_000),
    read_at: null,
  },
  {
    id: 'fx-notif-3',
    source: 'life',
    kind: 'goal',
    title: 'A step is ready',
    body: '“Outline the first chapter” is the next step for Write the book.',
    priority: 'high',
    link: { entity: 'goal', id: 'fx-goal-book' },
    session_id: null,
    created_at: iso(-26 * 3_600_000),
    read_at: iso(-25 * 3_600_000),
  },
]

function summary(plan: Plan) {
  const tasks = plan.items.filter((item) => item.kind !== 'event' && !item.deleted_at)
  return {
    planned: plan.items.length,
    done: plan.items.filter((item) => item.done_at).length,
    minutes_open: tasks.filter((item) => !item.done_at).reduce((sum, item) => sum + item.minutes, 0),
    minutes_done: tasks.filter((item) => item.done_at).reduce((sum, item) => sum + item.minutes, 0),
    minutes_events: plan.items.filter((item) => item.kind === 'event').reduce((sum, item) => sum + item.minutes, 0),
  }
}

function plan(): Plan {
  return {
    day: DAY,
    items: planItems,
    proposals: [],
    summary: summary({ day: DAY, items: planItems, summary: { planned: 0, done: 0, minutes_open: 0, minutes_done: 0, minutes_events: 0 } }),
  }
}

function goalById(id: unknown): Goal {
  const goal = goals.find((item) => item.id === id)
  if (!goal) throw new Error('That goal could not be found.')
  return goal
}

function viewStateFor(goalId: string, catalogId: string): ViewState {
  const goal = goalById(goalId)
  return {
    goal_id: goal.id,
    catalog_id: catalogId,
    view: goal.id === 'fx-goal-book' ? viewFor(catalogId) : null,
    measurements: measurements.filter((measurement) => measurement.goal_id === goalId),
  }
}

function recomputeGoal(goal: Goal): Goal {
  const steps = goal.steps ?? []
  goal.progress = {
    done: steps.filter((step) => step.done_at).length,
    total: steps.length,
  }
  goal.next_step = steps.find((step) => !step.done_at) ?? null
  return goal
}

function reminderAgenda(): ReminderAgenda {
  const items: AgendaItem[] = []
  for (const reminder of reminders) {
    if (!reminder.due_at || reminder.state === 'done') continue
    const due = reminder.snoozed_until ?? reminder.due_at
    items.push({
      reminder,
      at: due,
      state: new Date(due).getTime() <= Date.now() ? 'due' : 'upcoming',
      overdue: new Date(due).getTime() < Date.now() - 3_600_000,
    })
  }
  return { day: DAY, items }
}

function nextAction(): NextAction {
  return {
    suggestion: {
      title: 'Outline the first chapter',
      minutes: 25,
      reason: 'A small step toward Write the book.',
      source: 'goal_step',
      plan_item_id: null,
      goal_id: 'fx-goal-book',
      step_id: 'fx-step-2',
    },
  }
}

function randomId(prefix: string): string {
  return `fx-${prefix}-${Math.random().toString(36).slice(2, 8)}`
}

/* ---------- Clean-slate requests translated onto the fixture records ---------- */

function itemFromPlan(item: PlanItem): Item {
  return {
    id: item.id,
    kind: item.kind === 'event' ? 'event' : 'task',
    subject: 'person',
    title: item.title,
    notes: '',
    goal_id: item.goal_id,
    at: item.start_at,
    minutes: item.minutes,
    time_zone: ZONE,
    recurrence: item.id === 'fx-task-read' ? { freq: 'daily' } : null,
    alert_before_minutes: null,
    is_priority: item.is_priority,
    snoozed_until: null,
    done_at: item.done_at,
    version: item.version,
    deleted_at: null,
    created_at: item.created_at,
    updated_at: item.updated_at,
  }
}

function goalShape(goal: Goal): Goal {
  const nextStep = goal.next_step ?? goal.steps?.find((step) => !step.done_at) ?? null
  return {
    id: goal.id,
    subject: 'person',
    title: goal.title,
    notes: goal.why ?? '',
    ends_on: null,
    version: goal.version,
    progress: goal.progress,
    next: nextStep
      ? {
          id: nextStep.id,
          kind: 'task',
          subject: 'person',
          title: nextStep.title,
          notes: '',
          goal_id: goal.id,
          at: null,
          minutes: nextStep.minutes,
          version: nextStep.version,
          done_at: nextStep.done_at,
        }
      : null,
    created_at: goal.created_at,
    updated_at: goal.updated_at,
  }
}

function dayEntries(): DayEntry[] {
  const entries: DayEntry[] = []
  for (const item of planItems) {
    if (!item.start_at) continue
    const at = new Date(item.start_at)
    const overdue = item.kind !== 'event' && !item.done_at && at.getTime() < Date.now() && localDay(at) < DAY
    if (localDay(at) !== DAY && !overdue) continue
    entries.push({
      item: itemFromPlan(item),
      at: item.start_at,
      state:
        item.kind === 'event'
          ? at.getTime() < Date.now()
            ? 'past'
            : 'upcoming'
          : item.done_at
            ? 'done'
            : 'open',
      overdue,
    })
  }
  return entries.sort((a, b) => a.at.localeCompare(b.at))
}

function taskHistoryFor(id: string): TaskHistory {
  const found = routineStatuses.find(
    (item) => item.routine.id === id || (id === 'fx-task-read' && item.routine.id === 'fx-routine-read'),
  )
  if (!found) throw new Error('That task could not be found.')
  const history = historyFor(found)
  return {
    task: itemFromPlan(planItems.find((item) => item.id === id) ?? planItems[0]),
    days: history.days,
    last7: history.last_7,
    last30: history.last_30,
    streak: history.streak,
    best_streak: history.best_streak,
  }
}

export function fixtureLifeResponse(operation: string, input: Record<string, unknown>): unknown {
  switch (operation) {
    // Clean-slate names, served from the same fixture records as the older ones below.
    case 'day_get':
      return { day: DAY, entries: dayEntries() } satisfies Day
    case 'tasks_list': {
      const status = String(input.status ?? 'open')
      const goalId = input.goal_id ? String(input.goal_id) : null
      const items = planItems.filter(
        (item) =>
          item.kind !== 'event' &&
          (!goalId || item.goal_id === goalId) &&
          (status === 'all' || (status === 'done' ? Boolean(item.done_at) : !item.done_at)),
      )
      return { items: items.map(itemFromPlan), total: items.length, next_offset: null } satisfies Page<Item>
    }
    case 'calendar_events_list': {
      const goalId = input.goal_id ? String(input.goal_id) : null
      const items = planItems.filter((item) => item.kind === 'event' && (!goalId || item.goal_id === goalId))
      return { items: items.map(itemFromPlan), total: items.length, next_offset: null } satisfies Page<Item>
    }
    case 'tasks_get': {
      const item = planItems.find((candidate) => candidate.id === input.id && candidate.kind !== 'event')
      if (!item) throw new Error('That task could not be found.')
      return itemFromPlan(item)
    }
    case 'calendar_events_get': {
      const item = planItems.find((candidate) => candidate.id === input.id && candidate.kind === 'event')
      if (!item) throw new Error('That event could not be found.')
      return itemFromPlan(item)
    }
    case 'tasks_create': {
      const created = planItem({
        id: randomId('task'),
        title: String(input.title ?? 'New task'),
        minutes: Number(input.minutes ?? 25),
        is_priority: Boolean(input.is_priority),
        start_at: (input.at as string | null) ?? null,
        goal_id: (input.goal_id as string | null) ?? null,
      })
      planItems.unshift(created)
      return itemFromPlan(created)
    }
    case 'tasks_update': {
      const item = planItems.find((candidate) => candidate.id === input.id)
      if (!item) throw new Error('That task could not be found.')
      Object.assign(item, {
        title: input.title ?? item.title,
        minutes: input.minutes ?? item.minutes,
        start_at: input.at !== undefined ? input.at : item.start_at,
        is_priority: input.is_priority ?? item.is_priority,
        goal_id: input.goal_id !== undefined ? input.goal_id || null : item.goal_id,
        version: item.version + 1,
        updated_at: iso(0),
      })
      return itemFromPlan(item)
    }
    case 'tasks_complete': {
      const item = planItems.find((candidate) => candidate.id === input.id && candidate.kind !== 'event')
      if (!item) throw new Error('That task could not be found.')
      item.done_at = input.done === false ? null : iso(0)
      item.version += 1
      return itemFromPlan(item)
    }
    case 'tasks_delete': {
      const index = planItems.findIndex((candidate) => candidate.id === input.id && candidate.kind !== 'event')
      if (index >= 0) planItems.splice(index, 1)
      return {}
    }
    case 'tasks_snooze': {
      const item = planItems.find((candidate) => candidate.id === input.id && candidate.kind !== 'event')
      if (!item) throw new Error('That task could not be found.')
      return itemFromPlan(item)
    }
    case 'tasks_history':
      return taskHistoryFor(String(input.id))
    case 'calendar_events_create': {
      const created = planItem({
        id: randomId('event'),
        title: String(input.title ?? 'New event'),
        kind: 'event',
        minutes: Number(input.minutes ?? 60),
        start_at: String(input.at),
        goal_id: (input.goal_id as string | null) ?? null,
      })
      planItems.unshift(created)
      return itemFromPlan(created)
    }
    case 'calendar_events_update': {
      const item = planItems.find((candidate) => candidate.id === input.id && candidate.kind === 'event')
      if (!item) throw new Error('That event could not be found.')
      Object.assign(item, {
        title: input.title ?? item.title,
        minutes: input.minutes ?? item.minutes,
        start_at: input.at !== undefined ? input.at || item.start_at : item.start_at,
        goal_id: input.goal_id !== undefined ? input.goal_id || null : item.goal_id,
        version: item.version + 1,
        updated_at: iso(0),
      })
      return itemFromPlan(item)
    }
    case 'calendar_events_delete': {
      const index = planItems.findIndex((candidate) => candidate.id === input.id && candidate.kind === 'event')
      if (index >= 0) planItems.splice(index, 1)
      return {}
    }
    case 'calendar_events_snooze': {
      const item = planItems.find((candidate) => candidate.id === input.id && candidate.kind === 'event')
      if (!item) throw new Error('That event could not be found.')
      return itemFromPlan(item)
    }
    case 'measurements_record': {
      const created: Measurement = {
        id: randomId('measurement'),
        subject_kind: String(input.subject_kind ?? 'goal'),
        subject_id: String(input.subject_id ?? ''),
        metric_id: String(input.metric_id),
        value: Number(input.value),
        measured_at: String(input.measured_at ?? iso(0)),
        notes: (input.notes as string | null) ?? null,
        version: 1,
      }
      measurements.unshift(created)
      return created
    }
    case 'measurements_update': {
      const found = measurements.find((measurement) => measurement.id === input.id)
      if (!found) throw new Error('That measurement could not be found.')
      found.value = Number(input.value ?? found.value)
      found.measured_at = String(input.measured_at ?? found.measured_at)
      found.notes = (input.notes as string | null) ?? found.notes ?? null
      found.version += 1
      return found
    }
    case 'measurements_delete': {
      const index = measurements.findIndex((measurement) => measurement.id === input.id)
      if (index >= 0) measurements.splice(index, 1)
      return {}
    }

    case 'settings_get':
      return settings
    case 'settings_set':
      Object.assign(settings, {
        time_zone: input.time_zone ?? settings.time_zone,
        work_start: input.work_start ?? settings.work_start,
        work_end: input.work_end ?? settings.work_end,
        version: settings.version + 1,
      })
      return settings
    case 'plan_get':
      return plan()
    case 'next_action':
      return nextAction()
    case 'routines_status':
      return { day: DAY, items: routineStatuses }
    case 'routines_history': {
      const found = routineStatuses.find((item) => item.routine.id === input.routine_id)
      if (!found) throw new Error('That routine could not be found.')
      return historyFor(found)
    }
    case 'goals_list':
      return {
        items: goals.map(goalShape),
        total: goals.length,
        limit: 100,
        offset: 0,
        has_more: false,
      } satisfies Page<Goal>
    case 'goals_get':
      return goalShape(goalById(input.id))
    case 'reminders_list':
      return {
        items: reminders,
        total: reminders.length,
        limit: 200,
        offset: 0,
        has_more: false,
      } satisfies Page<Reminder>
    case 'reminders_agenda':
      return reminderAgenda()
    case 'views_state':
      return viewStateFor(String(input.subject_id ?? input.goal_id), String(input.catalog_id))
    case 'tracker_catalog_get':
      return { catalogs: [{ id: 'view-kit.v1' }] }

    case 'plan_items_create': {
      const item = planItem({
        id: randomId('task'),
        title: String(input.title ?? 'New task'),
        minutes: Number(input.minutes ?? 25),
        is_priority: Boolean(input.is_priority),
        day: String(input.day ?? DAY),
        start_at: (input.start_at as string | null) ?? null,
        goal_id: (input.goal_id as string | null) ?? null,
        step_id: (input.step_id as string | null) ?? null,
      })
      planItems.unshift(item)
      return item
    }
    case 'plan_items_update': {
      const item = planItems.find((candidate) => candidate.id === input.id)
      if (!item) throw new Error('That task could not be found.')
      Object.assign(item, {
        day: input.day ?? item.day,
        title: input.title ?? item.title,
        kind: input.kind ?? item.kind,
        minutes: input.minutes ?? item.minutes,
        start_at: input.start_at !== undefined ? input.start_at : item.start_at,
        is_priority: input.is_priority ?? item.is_priority,
        goal_id: input.goal_id !== undefined ? input.goal_id : item.goal_id,
        step_id: input.step_id !== undefined ? input.step_id : item.step_id,
        version: item.version + 1,
        updated_at: iso(0),
      })
      return item
    }
    case 'plan_items_complete': {
      const item = planItems.find((candidate) => candidate.id === input.id)
      if (!item) throw new Error('That task could not be found.')
      item.done_at = input.done ? iso(0) : null
      item.version += 1
      return item
    }
    case 'plan_items_delete': {
      const index = planItems.findIndex((candidate) => candidate.id === input.id)
      if (index >= 0) planItems.splice(index, 1)
      return {}
    }
    case 'plan_items_move': {
      const item = planItems.find((candidate) => candidate.id === input.id)
      if (item) {
        item.day = String(input.day ?? item.day)
        item.version += 1
      }
      return item
    }

    case 'routines_log': {
      const found = routineStatuses.find((item) => item.routine.id === input.routine_id)
      if (!found) throw new Error('That routine could not be found.')
      const delta = Number(input.delta ?? 1)
      found.count = Math.max(0, Math.min(found.target, found.count + delta))
      found.done = found.count >= found.target
      found.variant = (input.variant as string | null) ?? found.variant
      found.streak = found.done ? found.streak + 1 : found.streak
      found.hint = found.done
        ? 'Done for today.'
        : found.count > 0
          ? `${found.count} of ${found.target} today.`
          : 'Nothing recorded yet today.'
      Object.assign(found.routine, { version: found.routine.version + 1 })
      return found
    }
    case 'routines_create': {
      const created = routine({
        id: randomId('routine'),
        title: String(input.title ?? 'New routine'),
        minutes: Number(input.minutes ?? 10),
        shortTitle: (input.short_title as string | null) ?? undefined,
        shortMinutes: (input.short_minutes as number | null) ?? undefined,
        weekdays: Array.isArray(input.weekdays) ? (input.weekdays as number[]) : [],
        target: Number(input.target_per_day ?? 1),
        nudges: Array.isArray(input.nudges)
          ? (input.nudges as { at: string; message?: string | null }[])
          : [],
      })
      routineStatuses.unshift(
        status(created, { scheduled: true, count: 0, hint: 'Nothing recorded yet today.' }),
      )
      return created
    }
    case 'routines_delete': {
      const index = routineStatuses.findIndex((item) => item.routine.id === input.id)
      if (index >= 0) routineStatuses.splice(index, 1)
      return {}
    }
    case 'nudges_set': {
      const found = routineStatuses.find((item) => item.routine.id === input.id)
      if (!found) throw new Error('That routine could not be found.')
      const nudges = found.routine.nudges ?? []
      const at = String(input.at)
      const next = nudges.filter((nudge) => nudge.at !== at)
      next.push({ at, message: (input.message as string | null) ?? null })
      next.sort((a, b) => a.at.localeCompare(b.at))
      found.routine.nudges = next
      found.routine.version += 1
      return found.routine
    }
    case 'nudges_remove': {
      const found = routineStatuses.find((item) => item.routine.id === input.id)
      if (!found) throw new Error('That routine could not be found.')
      found.routine.nudges = (found.routine.nudges ?? []).filter((nudge) => nudge.at !== input.at)
      found.routine.version += 1
      return found.routine
    }

    case 'reminders_create': {
      const created: Reminder = {
        id: randomId('reminder'),
        title: String(input.title ?? 'New reminder'),
        notes: (input.notes as string | null) ?? null,
        due_at: (input.due_at as string | null) ?? null,
        snoozed_until: null,
        time_zone: String(input.time_zone ?? ZONE),
        recurrence: (input.recurrence as Reminder['recurrence']) ?? null,
        source: 'user',
        state: 'pending',
        version: 1,
        created_at: iso(0),
        updated_at: iso(0),
      }
      reminders.unshift(created)
      return created
    }
    case 'reminders_ack': {
      const reminder = reminders.find((item) => item.id === input.id)
      if (!reminder) throw new Error('That reminder could not be found.')
      return reminder
    }
    case 'reminders_complete': {
      const reminder = reminders.find((item) => item.id === input.id)
      if (!reminder) throw new Error('That reminder could not be found.')
      reminder.state = 'done'
      reminder.completed_at = iso(0)
      reminder.version += 1
      return reminder
    }
    case 'reminders_snooze': {
      const reminder = reminders.find((item) => item.id === input.id)
      if (!reminder) throw new Error('That reminder could not be found.')
      reminder.snoozed_until = String(input.until)
      reminder.version += 1
      return reminder
    }
    case 'reminders_delete': {
      const index = reminders.findIndex((item) => item.id === input.id)
      if (index >= 0) reminders.splice(index, 1)
      return {}
    }

    case 'steps_complete': {
      const goal = goals.find((candidate) =>
        (candidate.steps ?? []).some((step) => step.id === input.id),
      )
      const step = goal?.steps?.find((candidate) => candidate.id === input.id)
      if (!goal || !step) throw new Error('That step could not be found.')
      step.done_at = input.done ? iso(0) : null
      step.version += 1
      goal.version += 1
      return recomputeGoal(goal)
    }

    case 'goal_measurements_record': {
      const goal = goalById(input.goal_id)
      const measurement: Measurement = {
        id: randomId('measurement'),
        goal_id: goal.id,
        metric_id: String(input.metric_id),
        unit: metrics.find((metric) => metric.id === input.metric_id)?.unit ?? '',
        value: Number(input.value),
        measured_at: String(input.measured_at ?? iso(0)),
        notes: (input.notes as string | null) ?? null,
        version: 1,
      }
      measurements.push(measurement)
      goal.version += 1
      return measurement
    }
    case 'goal_measurements_update': {
      const measurement = measurements.find((item) => item.id === input.id)
      if (!measurement) throw new Error('That observation could not be found.')
      measurement.value = Number(input.value ?? measurement.value)
      measurement.measured_at = String(input.measured_at ?? measurement.measured_at)
      measurement.notes = (input.notes as string | null) ?? measurement.notes
      measurement.version += 1
      return measurement
    }
    case 'goal_measurements_delete': {
      const index = measurements.findIndex((item) => item.id === input.id)
      const removed = index >= 0 ? measurements.splice(index, 1)[0] : null
      return { ...removed, deleted_at: iso(0) }
    }

    default:
      throw new Error(`No fixture response for ${operation}.`)
  }
}

/** A data provider's answer: the weight series comes from the recorded weights, one point per day. */
export function fixtureProviderResponse(provider: string, operation: string, input: Record<string, unknown>): unknown {
  if (provider === 'health' && operation === 'series_get' && input.series === 'body_weight') {
    const points = measurements
      .filter((item) => item.metric_id === 'fx-m-weight')
      .map((item) => ({ t: localDay(new Date(item.measured_at)), value: item.value }))
    return { provider, series: 'body_weight', unit: 'kg', granularity: 'day', points } satisfies SeriesData
  }
  throw new Error(`No fixture data from ${provider} for ${operation}.`)
}

export async function fixtureNotificationResponse(
  path: string,
  method: string,
): Promise<unknown> {
  if (method === 'GET' && path.startsWith('/notifications')) {
    const unread = notifications.filter((item) => !item.read_at).length
    return { items: notifications, unread, next_before: null }
  }
  if (method === 'POST' && path === '/notifications/read-all') {
    let marked = 0
    for (const item of notifications) {
      if (!item.read_at) {
        item.read_at = iso(0)
        marked += 1
      }
    }
    return { marked }
  }
  if (method === 'POST' && path.startsWith('/notifications/') && path.endsWith('/read')) {
    const id = decodeURIComponent(path.slice('/notifications/'.length, -'/read'.length))
    const item = notifications.find((candidate) => candidate.id === id)
    if (item) item.read_at = iso(0)
    return undefined
  }
  throw new Error(`No fixture response for ${method} ${path}.`)
}

/* ---------- semantic memory ---------- */

const semanticItems: Record<'reflections' | 'about_you', SemanticMemoryItem[]> = {
  reflections: [
    {
      id: 'fx-reflection-1',
      kind: 'mental_model',
      title: 'You do your best work in the morning',
      content:
        'Across the last three weeks, the writing sessions you started before 10am ran **twice as long** as the ones after lunch.\n\nThe pattern is strongest on days when the first task is already chosen the night before.',
      created_at: iso(-21 * 86_400_000),
      updated_at: iso(-2 * 86_400_000),
      availability: 'complete',
      source_status: 'recorded',
      truncated: false,
      entities: [
        { id: 'fx-e-morning', name: 'Morning routine' },
        { id: 'fx-e-writing', name: 'Writing' },
      ],
      sources: [
        { id: 'fx-src-morning', title: 'Morning pages, week of 6 October', available: true },
        { id: 'fx-src-missing', title: 'An older note', available: false },
      ],
    },
    {
      id: 'fx-reflection-2',
      kind: 'mental_model',
      title: 'You are more consistent when the habit is small',
      content:
        'The routines you have kept longest are the ones with a short version you can do on a bad day. The ten-minute walk has survived two busy weeks; the longer plan did not.',
      created_at: iso(-32 * 86_400_000),
      updated_at: iso(-9 * 86_400_000),
      availability: 'partial',
      source_status: 'not_recorded',
      truncated: true,
      entities: [{ id: 'fx-e-walking', name: 'Walking' }],
    },
  ],
  about_you: [
    {
      id: 'fx-about-1',
      kind: 'personal_model',
      title: 'You are building toward a quieter, more deliberate year',
      content:
        'You have said yes to fewer obligations and kept more of the work that needs long attention. The book, the morning routine, and the shorter list all point the same way.',
      created_at: iso(-40 * 86_400_000),
      updated_at: iso(-86_400_000),
      availability: 'complete',
      source_status: 'partly_available',
      truncated: false,
      entities: [
        { id: 'fx-e-writing', name: 'Writing' },
        { id: 'fx-e-health', name: 'Health' },
      ],
      sources: [{ id: 'fx-src-values', title: 'Notes on what matters this year', available: true }],
    },
    {
      id: 'fx-about-2',
      kind: 'observation',
      title: 'You prefer a short list to a full schedule',
      content:
        'On days with more than five planned items, you finish fewer of them. A three-item list tends to get done.',
      created_at: iso(-12 * 86_400_000),
      updated_at: iso(-3 * 86_400_000),
      availability: 'complete',
      source_status: 'recorded',
      truncated: false,
      entities: [],
      sources: [],
    },
  ],
}

export function fixtureSemanticPage(
  section: 'reflections' | 'about_you',
  offset: number,
  limit: number,
): SemanticMemoryPage {
  const all = semanticItems[section]
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
      node('you', 'You', 'person', { role: 'founder and engineer', city: 'Lisbon', rhythm: 'decides in the morning' }, 42),
      node('agent-brain', 'Agent Brain', 'project', { status: 'active', stack: 'Postgres, Temporal' }, 31),
      node('mission-control', 'Mission Control', 'project', { platform: 'iOS and iPad' }, 18),
      node('dana', 'Dana', 'person', { role: 'designer' }, 9),
      node('acme', 'Acme', 'company', { industry: 'logistics' }, 7),
      node('lisbon', 'Lisbon', 'place', {}, 6),
      node('postgres', 'Postgres', 'tool', {}, 5),
      node('mara', 'Mara', undefined, {}, 2),
    ],
    edges: [
      edge('you', 'builds', 'agent-brain', 12),
      edge('you', 'builds', 'mission-control', 8),
      edge('you', 'lives_in', 'lisbon', 3),
      edge('dana', 'designs', 'mission-control', 4),
      edge('you', 'works_with', 'dana', 5),
      edge('dana', 'works_at', 'acme', 2),
      edge('agent-brain', 'uses', 'postgres', 6),
    ],
    truncated: false,
    limit: 100,
  }
}

export function fixtureSemanticSource(source: string): SemanticMemoryItem {
  const item = semanticItems.reflections
    .flatMap((entry) => entry.sources ?? [])
    .find((candidate) => candidate.id === source)
  return {
    id: source,
    kind: 'memory',
    title: item?.title ?? 'Supporting memory',
    content:
      item?.title === 'An older note'
        ? null
        : 'The note recorded three mornings in a row where the writing started before nine and ran past the planned hour.\n\n“The first sentence was already on the page. That seemed to be the whole trick.”',
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
    {
      id: 'fx-fact-2',
      text: 'The mornings that worked began with the first sentence already chosen.',
      network: 'experience',
      mention_time: iso(-9 * 86_400_000),
      entities: [{ id: 'fx-e-morning', name: 'Morning routine' }],
    },
  ],
  'fx-e-writing': [
    {
      id: 'fx-fact-3',
      text: 'The book has one completed milestone: choosing the through-line.',
      network: 'observation',
      mention_time: iso(-12 * 86_400_000),
      entities: [{ id: 'fx-e-writing', name: 'Writing' }],
    },
  ],
}

export function fixtureEntityFacts(entityId: string): MemoryFactsPage {
  return {
    bank_available: true,
    items: entityFacts[entityId] ?? [],
    has_more: false,
    limit: 20,
    offset: 0,
  }
}
