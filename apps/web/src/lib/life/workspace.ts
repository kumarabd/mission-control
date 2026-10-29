import type { CalendarEvent, Intention, Task } from './personal'

/** The records a turn can change, captured so the chat can say what it actually did. */
export type WorkspaceSnapshot = {
  intentions: Intention[]
  tasks: Task[]
  events: CalendarEvent[]
}

export type WorkspaceUpdate = {
  kind: 'intention' | 'task' | 'event'
  id: string
  title: string
  detail: string
}

export function workspaceSnapshot(input: WorkspaceSnapshot): WorkspaceSnapshot {
  return input
}

/**
 * Compare the workspace before and after a turn. A title/version change or a newly created record counts as an update.
 */
export function diffWorkspace(before: WorkspaceSnapshot | null, after: WorkspaceSnapshot): WorkspaceUpdate[] {
  if (!before) return []
  const updates: WorkspaceUpdate[] = []

  const intentionMap = new Map(before.intentions.map((record) => [record.id, record]))
  for (const record of after.intentions) {
    const previous = intentionMap.get(record.id)
    if (!previous) {
      updates.push({ kind: 'intention', id: record.id, title: record.title, detail: 'New intention' })
    } else if (previous.version !== record.version || previous.title !== record.title) {
      updates.push({ kind: 'intention', id: record.id, title: record.title, detail: 'Intention updated' })
    }
  }

  const taskMap = new Map(before.tasks.map((record) => [record.id, record]))
  for (const record of after.tasks) {
    const previous = taskMap.get(record.id)
    if (!previous) {
      updates.push({ kind: 'task', id: record.id, title: record.title, detail: 'New task' })
    } else if (previous.version !== record.version || previous.done_at !== record.done_at) {
      updates.push({ kind: 'task', id: record.id, title: record.title, detail: record.done_at ? 'Task complete' : 'Task updated' })
    }
  }

  const eventMap = new Map(before.events.map((record) => [record.id, record]))
  for (const record of after.events) {
    const previous = eventMap.get(record.id)
    if (!previous) {
      updates.push({ kind: 'event', id: record.id, title: record.title, detail: 'New event' })
    } else if (previous.version !== record.version || previous.at !== record.at) {
      updates.push({ kind: 'event', id: record.id, title: record.title, detail: 'Event updated' })
    }
  }

  return updates.slice(0, 6)
}
