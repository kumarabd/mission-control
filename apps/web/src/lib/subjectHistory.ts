import { SIGNAL_TIER_LABELS } from './agentPolicy'

type HistoryEvent = { written_at: string }

export type HistoryEventKind = 'active' | 'superseded' | 'contradicted' | string

export function historyEventLabel(event: string): string {
  switch (event) {
    case 'active':
      return 'Active'
    case 'superseded':
      return 'Superseded'
    case 'contradicted':
      return 'Contradicted'
    default:
      return event
  }
}

export function historyEventStyles(event: string): {
  border: string
  badge: string
  dot: string
} {
  switch (event) {
    case 'active':
      return {
        border: 'border-flat-secondary',
        badge: 'bg-flat-secondary text-flat-on-primary',
        dot: 'bg-flat-secondary',
      }
    case 'superseded':
      return {
        border: 'border-flat-border',
        badge: 'bg-flat-muted text-flat-muted-fg',
        dot: 'bg-flat-muted-fg',
      }
    case 'contradicted':
      return {
        border: 'border-flat-accent',
        badge: 'bg-flat-accent text-flat-on-primary',
        dot: 'bg-flat-accent',
      }
    default:
      return {
        border: 'border-flat-border',
        badge: 'bg-flat-muted text-flat-muted-fg',
        dot: 'bg-flat-muted-fg',
      }
  }
}

export function formatHistoryTier(tier: number): string {
  return SIGNAL_TIER_LABELS[tier] ?? `Tier ${tier}`
}

export function localInputToRFC3339(value: string): string | undefined {
  if (!value.trim()) return undefined
  const d = new Date(value)
  if (Number.isNaN(d.getTime())) return undefined
  return d.toISOString()
}

export function sortHistoryEvents(items: HistoryEvent[]): HistoryEvent[] {
  return [...items].sort(
    (a, b) => new Date(a.written_at).getTime() - new Date(b.written_at).getTime(),
  )
}
