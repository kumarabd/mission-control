import type { Goal, Item } from './wire'

export function goalProgress(goal: Goal): { done: number; total: number } {
  if (goal.progress) return goal.progress
  const steps = goal.steps ?? []
  const done = steps.filter((step) => step.done_at).length
  return { done, total: steps.length }
}

export function formatMinutes(minutes: number): string {
  if (!Number.isFinite(minutes) || minutes <= 0) return ''
  if (minutes < 60) return `${minutes} min`
  const hours = Math.floor(minutes / 60)
  const rest = minutes % 60
  return rest ? `${hours} hr ${rest} min` : `${hours} hr`
}

export type WorkspaceSnapshot = {
  goals: Goal[]
  tasks: Item[]
  events: Item[]
}

export type WorkspaceUpdate = {
  kind: 'goal' | 'task' | 'event'
  id: string
  title: string
  detail: string
}

export function workspaceSnapshot(input: WorkspaceSnapshot): WorkspaceSnapshot {
  return {
    goals: input.goals,
    tasks: input.tasks.filter((item) => item.kind === 'task'),
    events: input.events.filter((item) => item.kind === 'event'),
  }
}

/**
 * Native Life.swift derives receipts after a completed turn by comparing the
 * returned workspace records. A title/version change or a newly created record
 * counts as an update.
 */
export function diffWorkspace(before: WorkspaceSnapshot | null, after: WorkspaceSnapshot): WorkspaceUpdate[] {
  if (!before) return []
  const updates: WorkspaceUpdate[] = []

  const goalMap = new Map(before.goals.map((g) => [g.id, g]))
  for (const goal of after.goals) {
    const previous = goalMap.get(goal.id)
    if (!previous) {
      updates.push({ kind: 'goal', id: goal.id, title: goal.title, detail: 'New goal' })
    } else if (previous.version !== goal.version || previous.title !== goal.title) {
      updates.push({ kind: 'goal', id: goal.id, title: goal.title, detail: 'Goal updated' })
    }
  }

  const taskMap = new Map(before.tasks.map((t) => [t.id, t]))
  for (const task of after.tasks) {
    const previous = taskMap.get(task.id)
    if (!previous) {
      updates.push({ kind: 'task', id: task.id, title: task.title, detail: 'New task' })
    } else if (previous.version !== task.version || previous.done_at !== task.done_at) {
      updates.push({ kind: 'task', id: task.id, title: task.title, detail: task.done_at ? 'Task complete' : 'Task updated' })
    }
  }

  const eventMap = new Map(before.events.map((e) => [e.id, e]))
  for (const event of after.events) {
    const previous = eventMap.get(event.id)
    if (!previous) {
      updates.push({ kind: 'event', id: event.id, title: event.title, detail: 'New event' })
    } else if (previous.version !== event.version || previous.at !== event.at) {
      updates.push({ kind: 'event', id: event.id, title: event.title, detail: 'Event updated' })
    }
  }

  return updates.slice(0, 6)
}
