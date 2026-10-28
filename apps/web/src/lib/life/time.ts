/** Local calendar day: YYYY-MM-DD. Parse at local noon to avoid UTC shifts. */
export function localDay(date: Date = new Date()): string {
  const y = date.getFullYear()
  const m = String(date.getMonth() + 1).padStart(2, '0')
  const d = String(date.getDate()).padStart(2, '0')
  return `${y}-${m}-${d}`
}

export function parseDay(day: string): Date {
  const [y, m, d] = day.split('-').map(Number)
  return new Date(y, (m || 1) - 1, d || 1, 12, 0, 0, 0)
}

export function addDays(day: string, delta: number): string {
  const date = parseDay(day)
  date.setDate(date.getDate() + delta)
  return localDay(date)
}

/** The window a bound metric is drawn over: the last `days` days, ending today. */
export function seriesRange(days = 90, now: Date = new Date()): { from: string; to: string } {
  const to = localDay(now)
  return { from: addDays(to, -days), to }
}

export function formatDay(day: string, options: Intl.DateTimeFormatOptions = { weekday: 'long', month: 'long', day: 'numeric' }): string {
  return new Intl.DateTimeFormat(undefined, options).format(parseDay(day))
}

export function formatTime(iso: string | null | undefined): string {
  if (!iso) return ''
  const date = new Date(iso)
  if (Number.isNaN(date.getTime())) return ''
  return new Intl.DateTimeFormat(undefined, { hour: 'numeric', minute: '2-digit' }).format(date)
}

export function formatDateTime(iso: string | null | undefined): string {
  if (!iso) return ''
  const date = new Date(iso)
  if (Number.isNaN(date.getTime())) return ''
  return new Intl.DateTimeFormat(undefined, { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' }).format(date)
}

/** RFC3339 instant → value for an `<input type="datetime-local">` in the browser's zone. */
export function toDateTimeLocal(iso: string | null | undefined): string {
  if (!iso) return ''
  const date = new Date(iso)
  if (Number.isNaN(date.getTime())) return ''
  const pad = (value: number) => String(value).padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`
}

/** Value for `<input type="datetime-local">` from a local Date. */
export function dateTimeLocalValue(date: Date): string {
  const pad = (value: number) => String(value).padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`
}

export function isSameDay(iso: string | null | undefined, day: string): boolean {
  if (!iso) return false
  const date = new Date(iso)
  return !Number.isNaN(date.getTime()) && localDay(date) === day
}

export function resolvedTimeZone(): string {
  return Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC'
}

/** Browser timezone aliases that mean the same zone; avoids repeated settings writes. */
const TIME_ZONE_ALIASES: Record<string, string> = {
  'Asia/Calcutta': 'Asia/Kolkata',
  'Asia/Katmandu': 'Asia/Kathmandu',
  'Asia/Rangoon': 'Asia/Yangon',
  'America/Godthab': 'America/Nuuk',
}

export function normalizeTimeZone(zone: string): string {
  return TIME_ZONE_ALIASES[zone] ?? zone
}

export function timeZoneMatches(a: string | null | undefined, b: string | null | undefined): boolean {
  if (!a || !b) return false
  return normalizeTimeZone(a) === normalizeTimeZone(b)
}
