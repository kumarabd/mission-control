export type SortDirection = 'asc' | 'desc'

export function matchesSearch(query: string, ...fields: (string | null | undefined)[]): boolean {
  const q = query.trim().toLowerCase()
  if (!q) return true
  return fields.some((field) => (field ?? '').toLowerCase().includes(q))
}

export function compareValues(
  a: string | number | null | undefined,
  b: string | number | null | undefined,
  direction: SortDirection,
): number {
  const mult = direction === 'asc' ? 1 : -1
  if (a == null && b == null) return 0
  if (a == null) return 1
  if (b == null) return -1
  if (typeof a === 'number' && typeof b === 'number') {
    return (a - b) * mult
  }
  return String(a).localeCompare(String(b), undefined, { sensitivity: 'base' }) * mult
}

export function sortItems<T>(
  items: T[],
  getter: (item: T) => string | number | null | undefined,
  direction: SortDirection,
): T[] {
  return [...items].sort((a, b) => compareValues(getter(a), getter(b), direction))
}

export function uniqueSorted(values: (string | null | undefined)[]): string[] {
  return [...new Set(values.filter((v): v is string => Boolean(v?.trim())))].sort((a, b) =>
    a.localeCompare(b),
  )
}

/** Empty selection means no filter (match all). */
export function matchesMultiFilter(selected: string[], value: string): boolean {
  if (selected.length === 0) {
    return true
  }
  return selected.includes(value)
}

export function parseTime(value: string | null | undefined): number | null {
  if (!value) return null
  const t = Date.parse(value)
  return Number.isNaN(t) ? null : t
}

export function formatPreferenceValue(value: unknown): string {
  if (typeof value === 'string') return value
  if (value == null) return ''
  return JSON.stringify(value, null, 2)
}
