/**
 * The World's visual grammar: every entity is a seal whose silhouette says what
 * kind of thing it is, whose size says how connected it is, and whose colour
 * ties it to the legend. Labels stay beneath the seal, never inside a dashboard
 * card, so the graph reads as a map first and a list second.
 */

export const WORLD_MONO = '"IBM Plex Mono", ui-monospace, monospace'

export type WorldShape = 'circle' | 'diamond' | 'hexagon' | 'square' | 'octagon' | 'pentagon' | 'dashed'
export type WorldKind = 'organization' | 'team' | 'place' | 'project' | 'tool' | 'event' | 'person' | 'concept' | 'other'

export function kindForType(type?: string): WorldKind {
  const name = type?.toLowerCase() ?? ''
  if (/(organi[sz]ation|company|business)/.test(name)) return 'organization'
  if (/(team|club|group)/.test(name)) return 'team'
  if (/(place|location|city|country|island|venue|address|street)/.test(name)) return 'place'
  if (/(project|initiative|session|conversation|thread)/.test(name)) return 'project'
  if (/(tool|api|service|mcp|model|skill|library)/.test(name)) return 'tool'
  if (/(event|meeting|match|fixture|appointment)/.test(name)) return 'event'
  if (/(person|people|athlete|player|user|actor|author|contact)/.test(name)) return 'person'
  if (/(concept|idea|theme|topic|goal|habit)/.test(name)) return 'concept'
  return 'other'
}

export function shapeForType(type?: string): WorldShape {
  switch (kindForType(type)) {
    case 'organization':
    case 'team':
      return 'octagon'
    case 'place':
      return 'diamond'
    case 'project':
      return 'hexagon'
    case 'tool':
      return 'square'
    case 'event':
      return 'pentagon'
    case 'person':
      return 'circle'
    case 'concept':
      return 'dashed'
    case 'other':
      return type == null || type.toLowerCase().includes('unknown') ? 'dashed' : 'circle'
  }
}

export function markSize(degree: number): number {
  return 40 + Math.min(degree, 10) * 1.2
}

export function orbitSize(degree: number): number {
  return Math.max(markSize(degree) + 10, 56 + Math.min(degree, 10) * 0.6)
}
