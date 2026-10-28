/**
 * Places the world's entities on a canvas. Deterministic: the same entities and relations always land in the
 * same places, so the picture does not shuffle on every refresh. Entities that have relations are placed by a
 * force simulation; entities with none are laid out in a grid underneath, so a long list of unrelated things
 * never crowds the connected part. Mirrors the layout in Mission Control (WorldLayout.swift).
 */

export const NODE_W = 136
export const NODE_H = 54
export const MARGIN = 40

export type Point = { x: number; y: number }

export type WorldLayoutResult = {
  /** Node centres by id. */
  centers: Record<string, Point>
  width: number
  height: number
  /** Where the grid of unrelated entities begins, or null when there are none. */
  isolatedTop: number | null
}

/**
 * @param aspect the width to height the connected part should lean toward (1 is square; a wide panel wants more, a
 *   phone held upright wants less). It shapes the picture; it never causes overlap.
 */
export function layoutWorld(ids: string[], edges: Array<[string, string]>, aspect = 1): WorldLayoutResult {
  const index = new Map(ids.map((id, i) => [id, i]))
  const seen = new Set<string>()
  const pairs: Array<[number, number]> = []
  for (const [a, b] of edges) {
    const ia = index.get(a)
    const ib = index.get(b)
    if (a === b || ia === undefined || ib === undefined) continue
    const key = a < b ? `${a}\u0001${b}` : `${b}\u0001${a}`
    if (seen.has(key)) continue
    seen.add(key)
    pairs.push([ia, ib])
  }
  const degree = new Array<number>(ids.length).fill(0)
  for (const [a, b] of pairs) {
    degree[a]++
    degree[b]++
  }
  const connected = ids.map((_, i) => i).filter((i) => degree[i] > 0)
  const isolated = ids.map((_, i) => i).filter((i) => degree[i] === 0)

  const centers: Record<string, Point> = {}
  let width = 0
  let height = 0
  if (connected.length) {
    const local = new Map(connected.map((node, i) => [node, i]))
    const local_pairs = pairs
      .map(([a, b]) => [local.get(a), local.get(b)] as [number | undefined, number | undefined])
      .filter((p): p is [number, number] => p[0] !== undefined && p[1] !== undefined)
    const points = simulate(connected.length, local_pairs, aspect)
    connected.forEach((node, i) => {
      centers[ids[node]] = points[i]
    })
    const xs = points.map((p) => p.x)
    const ys = points.map((p) => p.y)
    const minX = Math.min(...xs) - NODE_W / 2
    const minY = Math.min(...ys) - NODE_H / 2
    for (const key of Object.keys(centers)) {
      centers[key] = { x: centers[key].x + MARGIN - minX, y: centers[key].y + MARGIN - minY }
    }
    width = Math.max(...xs) + NODE_W / 2 - minX + 2 * MARGIN
    height = Math.max(...ys) + NODE_H / 2 - minY + 2 * MARGIN
  }

  let isolatedTop: number | null = null
  if (isolated.length) {
    const gap = 20
    const canvasWidth = Math.max(width, 3 * NODE_W + 2 * gap + 2 * MARGIN)
    const columns = Math.max(1, Math.floor((canvasWidth - 2 * MARGIN + gap) / (NODE_W + gap)))
    const top = connected.length ? height : MARGIN
    isolatedTop = top
    const startY = top + 28
    isolated.forEach((node, i) => {
      centers[ids[node]] = {
        x: MARGIN + NODE_W / 2 + (i % columns) * (NODE_W + gap),
        y: startY + NODE_H / 2 + Math.floor(i / columns) * (NODE_H + gap),
      }
    })
    const rows = Math.ceil(isolated.length / columns)
    width = canvasWidth
    height = startY + rows * (NODE_H + gap) - gap + MARGIN
  }
  return { centers, width: Math.max(width, 1), height: Math.max(height, 1), isolatedTop }
}

/** Fruchterman–Reingold, then a few passes that push overlapping cards apart. */
function simulate(n: number, edges: Array<[number, number]>, aspect: number): Point[] {
  const side = Math.max(360, Math.ceil(Math.sqrt(n)) * 190)
  const k = Math.sqrt((side * side) / n) * 0.85
  // Golden-angle spiral: spread out and deterministic, so no two nodes start on top of each other.
  const position: Point[] = Array.from({ length: n }, (_, i) => {
    const angle = i * 2.399963229728653
    const radius = side * 0.42 * Math.sqrt((i + 1) / n)
    return { x: side / 2 + radius * Math.cos(angle), y: side / 2 + radius * Math.sin(angle) }
  })
  const iterations = 260
  for (let step = 0; step < iterations; step++) {
    const temperature = (side / 8) * (1 - step / iterations) + 1
    const move: Point[] = Array.from({ length: n }, () => ({ x: 0, y: 0 }))
    for (let i = 0; i < n; i++) {
      for (let j = i + 1; j < n; j++) {
        let dx = position[i].x - position[j].x
        let dy = position[i].y - position[j].y
        let distance = Math.hypot(dx, dy)
        if (distance < 0.01) {
          dx = 0.01 * (i + 1)
          dy = 0.01
          distance = Math.hypot(dx, dy)
        }
        const force = (k * k) / distance
        const fx = (dx / distance) * force
        const fy = (dy / distance) * force
        move[i].x += fx
        move[i].y += fy
        move[j].x -= fx
        move[j].y -= fy
      }
    }
    for (const [a, b] of edges) {
      const dx = position[a].x - position[b].x
      const dy = position[a].y - position[b].y
      const distance = Math.max(Math.hypot(dx, dy), 0.01)
      const force = (distance * distance) / k
      const fx = (dx / distance) * force
      const fy = (dy / distance) * force
      move[a].x -= fx
      move[a].y -= fy
      move[b].x += fx
      move[b].y += fy
    }
    for (let i = 0; i < n; i++) {
      move[i].x -= (position[i].x - side / 2) * 0.06 * (k / 100)
      move[i].y -= (position[i].y - side / 2) * 0.06 * (k / 100)
      const length = Math.max(Math.hypot(move[i].x, move[i].y), 0.01)
      const limited = Math.min(length, temperature)
      position[i].x += (move[i].x / length) * limited
      position[i].y += (move[i].y / length) * limited
    }
  }
  // The simulation ran with y stretched by `aspect`; bring it back before cards are separated.
  for (const p of position) p.y /= aspect
  // Cards are rectangles, not points: separate any that still overlap along the shallower axis.
  const gapX = 28
  const gapY = 36
  for (let pass = 0; pass < 40; pass++) {
    let moved = false
    for (let i = 0; i < n; i++) {
      for (let j = i + 1; j < n; j++) {
        const dx = position[j].x - position[i].x
        const dy = position[j].y - position[i].y
        const overlapX = NODE_W + gapX - Math.abs(dx)
        const overlapY = NODE_H + gapY - Math.abs(dy)
        if (overlapX <= 0 || overlapY <= 0) continue
        moved = true
        if (overlapX < overlapY) {
          const push = (overlapX / 2) * (dx >= 0 ? 1 : -1)
          position[i].x -= push
          position[j].x += push
        } else {
          const push = (overlapY / 2) * (dy >= 0 ? 1 : -1)
          position[i].y -= push
          position[j].y += push
        }
      }
    }
    if (!moved) break
  }
  return position
}

/** Where the line from a card's centre toward another point leaves the card's rectangle (with a small gap). */
export function borderPoint(center: Point, toward: Point, pad = 3): Point {
  const dx = toward.x - center.x
  const dy = toward.y - center.y
  if (dx === 0 && dy === 0) return center
  const hw = NODE_W / 2 + pad
  const hh = NODE_H / 2 + pad
  const scale = Math.min(dx === 0 ? Infinity : hw / Math.abs(dx), dy === 0 ? Infinity : hh / Math.abs(dy))
  return { x: center.x + dx * scale, y: center.y + dy * scale }
}
