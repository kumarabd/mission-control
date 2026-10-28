import { describe, expect, it } from 'vitest'
import { diffWorkspace, workspaceSnapshot } from './model'
import type { Goal, Item } from './wire'

function goal(id: string, extra: Partial<Goal> = {}): Goal {
  return { id, title: id, version: 1, progress: { done: 0, total: 0 }, ...extra }
}

function item(id: string, extra: Partial<Item> = {}): Item {
  return { id, kind: 'task', title: id, version: 1, ...extra }
}

describe('Workspace receipts', () => {
  it('diffs goals, tasks and events', () => {
    const before = workspaceSnapshot({
      goals: [goal('g1')],
      tasks: [item('t1')],
      events: [item('ev1', { kind: 'event', at: '2026-01-15T10:00:00Z' })],
    })
    const after = workspaceSnapshot({
      goals: [goal('g1', { version: 2 }), goal('g2')],
      tasks: [item('t1', { done_at: '2026-01-15T12:00:00Z' })],
      events: [item('ev1', { kind: 'event', at: '2026-01-16T10:00:00Z' })],
    })

    const updates = diffWorkspace(before, after)
    expect(updates.map((update) => `${update.kind}:${update.id}`)).toEqual([
      'goal:g1',
      'goal:g2',
      'task:t1',
      'event:ev1',
    ])
    expect(workspaceSnapshot({ goals: [], tasks: [], events: [] }).tasks).toEqual([])
  })

  it('returns nothing without a before snapshot and caps receipts at six', () => {
    expect(diffWorkspace(null, workspaceSnapshot({ goals: [], tasks: [], events: [] }))).toEqual([])
    const after = workspaceSnapshot({
      goals: [],
      tasks: Array.from({ length: 8 }, (_, index) => item(`t${index}`)),
      events: [],
    })
    expect(diffWorkspace(workspaceSnapshot({ goals: [], tasks: [], events: [] }), after)).toHaveLength(6)
  })
})
