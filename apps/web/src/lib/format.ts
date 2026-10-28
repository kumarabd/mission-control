export function isOverdue(
  dueAt: string | null | undefined,
  now: number,
  status?: string,
): boolean {
  if (!dueAt || status === 'complete') return false
  return new Date(dueAt).getTime() < now
}

export function formatDateTime(value?: string | null) {
  if (!value) return '—'
  return new Date(value).toLocaleString()
}

export function formatRelative(value?: string | null) {
  if (!value) return '—'
  const date = new Date(value).getTime()
  const diffMs = Date.now() - date
  const mins = Math.round(diffMs / 60000)
  if (mins < 1) return 'just now'
  if (mins < 60) return `${mins}m ago`
  const hours = Math.round(mins / 60)
  if (hours < 24) return `${hours}h ago`
  const days = Math.round(hours / 24)
  return `${days}d ago`
}
