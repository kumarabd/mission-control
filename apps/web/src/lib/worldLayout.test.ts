import { describe, expect, it } from 'vitest'
import { borderPoint, layoutWorld, NODE_H, NODE_W } from './worldLayout'

const ids = Array.from({ length: 12 }, (_, i) => `e${i}`)
const edges: Array<[string, string]> = [
  ['e0', 'e1'], ['e0', 'e2'], ['e1', 'e3'], ['e4', 'e5'], ['e5', 'e6'], ['e6', 'e4'], ['e7', 'e0'],
]

function overlaps(centers: Record<string, { x: number; y: number }>) {
  const list = Object.entries(centers)
  for (let i = 0; i < list.length; i++) {
    for (let j = i + 1; j < list.length; j++) {
      const dx = Math.abs(list[i][1].x - list[j][1].x)
      const dy = Math.abs(list[i][1].y - list[j][1].y)
      if (dx < NODE_W - 0.5 && dy < NODE_H - 0.5) return `${list[i][0]} overlaps ${list[j][0]}`
    }
  }
  return null
}

describe('world layout', () => {
  it('is deterministic', () => {
    expect(layoutWorld(ids, edges)).toEqual(layoutWorld(ids, edges))
  })

  it('places every card inside the canvas without overlaps', () => {
    const layout = layoutWorld(ids, edges)
    expect(Object.keys(layout.centers)).toHaveLength(ids.length)
    for (const c of Object.values(layout.centers)) {
      expect(c.x - NODE_W / 2).toBeGreaterThanOrEqual(0)
      expect(c.x + NODE_W / 2).toBeLessThanOrEqual(layout.width)
      expect(c.y - NODE_H / 2).toBeGreaterThanOrEqual(0)
      expect(c.y + NODE_H / 2).toBeLessThanOrEqual(layout.height)
    }
    expect(overlaps(layout.centers)).toBeNull()
  })

  it('puts entities with no relation in a grid below the connected part', () => {
    const layout = layoutWorld(ids, edges)
    expect(layout.isolatedTop).not.toBeNull()
    for (const id of ['e8', 'e9', 'e10', 'e11']) expect(layout.centers[id].y).toBeGreaterThan(layout.isolatedTop!)
    for (const id of ['e0', 'e1', 'e2', 'e3', 'e4', 'e5', 'e6', 'e7']) expect(layout.centers[id].y).toBeLessThan(layout.isolatedTop!)
  })

  it('keeps related entities closer than unrelated ones', () => {
    const { centers } = layoutWorld(ids, edges)
    const d = (a: string, b: string) => Math.hypot(centers[a].x - centers[b].x, centers[a].y - centers[b].y)
    const related = edges.reduce((sum, [a, b]) => sum + d(a, b), 0) / edges.length
    const unrelated = ([['e0', 'e5'], ['e1', 'e6'], ['e2', 'e4'], ['e3', 'e6']] as Array<[string, string]>).reduce((s, [a, b]) => s + d(a, b), 0) / 4
    expect(related).toBeLessThan(unrelated)
  })

  it('ignores unknown ids, self loops and repeats, and survives empty input', () => {
    const odd = layoutWorld(['a', 'b'], [['a', 'a'], ['a', 'zzz'], ['b', 'b']])
    expect(Object.keys(odd.centers)).toHaveLength(2)
    expect(odd.isolatedTop).not.toBeNull()
    expect(layoutWorld(['a', 'b'], [['a', 'b']])).toEqual(layoutWorld(['a', 'b'], [['a', 'b'], ['b', 'a'], ['a', 'b']]))
    expect(layoutWorld([], []).centers).toEqual({})
    const one = layoutWorld(['solo'], [])
    expect(one.centers.solo).toBeDefined()
    expect(one.width).toBeGreaterThan(0)
  })

  it('stays bounded and overlap-free for a larger graph', () => {
    const many = Array.from({ length: 60 }, (_, i) => `n${i}`)
    const chain: Array<[string, string]> = many.slice(1).map((id, i) => [many[Math.floor((i + 1) / 2)], id])
    const layout = layoutWorld(many, chain)
    expect(layout.width).toBeLessThan(6000)
    expect(layout.height).toBeLessThan(6000)
    expect(overlaps(layout.centers)).toBeNull()
  })

  it('leans wider when asked, without overlapping', () => {
    const square = layoutWorld(ids, edges, 1)
    const wide = layoutWorld(ids, edges, 2)
    const tall = layoutWorld(ids, edges, 0.6)
    const ratio = (l: { width: number; height: number; isolatedTop: number | null }) => l.width / (l.isolatedTop ?? l.height)
    expect(ratio(wide)).toBeGreaterThan(ratio(square))
    expect(ratio(tall)).toBeLessThan(ratio(square))
    expect(overlaps(wide.centers)).toBeNull()
    expect(overlaps(tall.centers)).toBeNull()
  })

  it('leaves a card on its border, toward the other card', () => {
    const p = borderPoint({ x: 0, y: 0 }, { x: 1000, y: 0 })
    expect(p.y).toBe(0)
    expect(p.x).toBeCloseTo(NODE_W / 2 + 3)
    const q = borderPoint({ x: 0, y: 0 }, { x: 0, y: -500 })
    expect(q.x).toBe(0)
    expect(q.y).toBeCloseTo(-(NODE_H / 2 + 3))
  })
})
