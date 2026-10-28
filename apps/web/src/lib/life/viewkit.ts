import type { Calc, KitWindow, Slot } from './wire'

/**
 * Evaluates the view kit's calculations on live data. A view's numbers are never written by the model: a block names a
 * metric and a function from the engine's catalogue, and this turns them into a figure. It mirrors the iOS evaluator and
 * both pass the same vectors (the engine's viewkit-vectors.json). Weeks start on Monday.
 */

/** A dated value; `date` is any time on its local day. */
export type Point = { date: Date; value: number }
/** A number, a date, or null when it cannot be known (data not arrived, or nothing sensible to say). */
export type KitValue = number | Date | null

/**
 * What the calculations read. `series[metric]` is absent when that metric's data has not arrived, which makes every
 * calculation over it unknown; an empty array means it arrived and has no records.
 */
export type KitData = { series: Record<string, Point[]>; now: Date }

export function kitData(series: Record<string, Point[]>, now: Date = new Date()): KitData {
  const sorted: Record<string, Point[]> = {}
  for (const [id, points] of Object.entries(series)) sorted[id] = [...points].sort((a, b) => a.date.getTime() - b.date.getTime())
  return { series: sorted, now }
}

// Dates: whole local days, counted from a day number so daylight-saving shifts cannot move a day.
export function dayIndex(date: Date): number {
  return Math.floor(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()) / 86_400_000)
}
function dayAt(index: number): Date {
  const utc = new Date(index * 86_400_000)
  return new Date(utc.getUTCFullYear(), utc.getUTCMonth(), utc.getUTCDate())
}
export function startOfDay(date: Date): Date {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate())
}
const today = (data: KitData) => dayIndex(data.now)

export function parseKitDate(text: string): Date | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(text)
  if (!match) return null
  const date = new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3]))
  return Number.isNaN(date.getTime()) ? null : date
}

/** The first day of the calendar week (Monday) or month holding `date`. */
export function periodStart(period: string, date: Date): number {
  const index = dayIndex(date)
  if (period === 'week') return index - ((date.getDay() + 6) % 7)
  return dayIndex(new Date(date.getFullYear(), date.getMonth(), 1))
}
/** The first day after that week or month. */
export function periodEnd(period: string, date: Date): number {
  if (period === 'week') return periodStart('week', date) + 7
  return dayIndex(new Date(date.getFullYear(), date.getMonth() + 1, 1))
}

export function pointsIn(metric: string, window: KitWindow | null | undefined, data: KitData): Point[] | null {
  const all = data.series[metric]
  if (!all) return null
  if (!window) return all
  const now = today(data)
  if (window.period) {
    const start = periodStart(window.period, data.now), end = periodEnd(window.period, data.now)
    return all.filter((p) => dayIndex(p.date) >= start && dayIndex(p.date) < end)
  }
  if (window.days) {
    const from = now - (Math.max(window.days, 1) - 1)
    return all.filter((p) => dayIndex(p.date) >= from && dayIndex(p.date) <= now)
  }
  return all
}

const finite = (n: number | null | undefined): KitValue => (n != null && Number.isFinite(n) ? n : null)

export function evaluate(calc: Calc, data: KitData): KitValue {
  const now = today(data)
  const numbers = (): number[] | null => {
    const values = (calc.args ?? []).map((a) => evaluate(a, data))
    return values.every((v): v is number => typeof v === 'number') ? values : null
  }
  const series = (metric?: string | null) => (metric ? data.series[metric] : undefined)
  switch (calc.fn) {
    case 'const': return finite(calc.value)
    case 'date': return calc.date ? parseKitDate(calc.date) : null
    case 'latest': return finite(series(calc.metric)?.at(-1)?.value)
    case 'first': return finite(series(calc.metric)?.[0]?.value)
    case 'sum': {
      const p = calc.metric ? pointsIn(calc.metric, calc.window, data) : null
      return p ? p.reduce((a, b) => a + b.value, 0) : null
    }
    case 'mean': {
      const p = calc.metric ? pointsIn(calc.metric, calc.window, data) : null
      return p && p.length > 0 ? finite(p.reduce((a, b) => a + b.value, 0) / p.length) : null
    }
    case 'count': {
      const p = calc.metric ? pointsIn(calc.metric, calc.window, data) : null
      return p ? new Set(p.filter((x) => x.value > 0).map((x) => dayIndex(x.date))).size : null
    }
    case 'add': { const a = numbers(); return a ? a.reduce((x, y) => x + y, 0) : null }
    case 'mul': { const a = numbers(); return a ? a.reduce((x, y) => x * y, 1) : null }
    case 'min': { const a = numbers(); return a && a.length ? Math.min(...a) : null }
    case 'max': { const a = numbers(); return a && a.length ? Math.max(...a) : null }
    case 'sub': { const a = numbers(); return a && a.length === 2 ? finite(a[0] - a[1]) : null }
    case 'div': { const a = numbers(); return a && a.length === 2 && a[1] !== 0 ? finite(a[0] / a[1]) : null }
    case 'days_left': {
      if (calc.period) return Math.max(0, periodEnd(calc.period, data.now) - 1 - now)
      const target = calc.date ? parseKitDate(calc.date) : null
      return target ? Math.max(0, dayIndex(target) - now) : null
    }
    case 'elapsed': {
      if (!calc.period) return null
      const start = periodStart(calc.period, data.now), total = periodEnd(calc.period, data.now) - start
      return total > 0 ? (now - start + 1) / total : null
    }
    case 'project': {
      if (!calc.metric || !calc.period) return null
      const sum = evaluate({ fn: 'sum', metric: calc.metric, window: { period: calc.period } }, data)
      const elapsed = evaluate({ fn: 'elapsed', period: calc.period }, data)
      return typeof sum === 'number' && typeof elapsed === 'number' && elapsed > 0 ? finite(sum / elapsed) : null
    }
    case 'rate': {
      const perDays = ({ day: 1, week: 7, month: 365.25 / 12 } as Record<string, number>)[calc.per ?? '']
      const r = calc.metric ? dailyRate(calc.metric, data) : null
      return perDays && r != null ? finite(r * perDays) : null
    }
    case 'eta': {
      const target = numbers()?.[0]
      const latest = series(calc.metric)?.at(-1)?.value
      const r = calc.metric ? dailyRate(calc.metric, data) : null
      if (target == null || latest == null || r == null || r === 0) return null
      const away = (target - latest) / r
      return Number.isFinite(away) && away >= 0 && away < 36_500 ? dayAt(now + Math.ceil(away)) : null
    }
    case 'streak': {
      const p = series(calc.metric)
      if (!p) return null
      const done = new Set(p.filter((x) => x.value > 0).map((x) => dayIndex(x.date)))
      let day = done.has(now) ? now : now - 1, n = 0
      while (done.has(day)) { n += 1; day -= 1 }
      return n
    }
    default: return null
  }
}

/** Change per day from the first to the latest value; null with fewer than two days of data. */
function dailyRate(metric: string, data: KitData): number | null {
  const p = data.series[metric]
  if (!p || p.length === 0) return null
  const days = dayIndex(p[p.length - 1].date) - dayIndex(p[0].date)
  return days > 0 ? (p[p.length - 1].value - p[0].value) / days : null
}

/** A series as drawn: the window applied, then grouped by day, week or month when asked. */
export function bucketed(
  metric: string, window: KitWindow | null | undefined, bucket: string | null | undefined, aggregate: string | null | undefined, data: KitData,
): Point[] | null {
  const p = pointsIn(metric, window, data)
  if (!p) return null
  if (!bucket) return p
  const groups = new Map<number, number[]>()
  for (const point of p) {
    const key = bucket === 'day' ? dayIndex(point.date) : periodStart(bucket, point.date)
    groups.set(key, [...(groups.get(key) ?? []), point.value])
  }
  return [...groups.keys()].sort((a, b) => a - b).map((key) => {
    const v = groups.get(key) ?? []
    const value = aggregate === 'mean' ? v.reduce((a, b) => a + b, 0) / v.length : aggregate === 'last' ? v[v.length - 1] : v.reduce((a, b) => a + b, 0)
    return { date: dayAt(key), value }
  })
}

export function formatKitValue(
  value: KitValue, format: string | null | undefined, unit: string | null | undefined, decimals: number | null | undefined, locale?: string,
): string | null {
  if (value == null) return null
  if (value instanceof Date) return new Intl.DateTimeFormat(locale, { day: 'numeric', month: 'short' }).format(value)
  const n = value
  switch (format ?? 'number') {
    case 'money': {
      const digits = decimals ?? (Math.abs(n) >= 100 || n === Math.round(n) ? 0 : 2)
      return new Intl.NumberFormat(locale, { style: 'currency', currency: unit || 'USD', minimumFractionDigits: digits, maximumFractionDigits: digits }).format(n)
    }
    case 'percent':
      return new Intl.NumberFormat(locale, { style: 'percent', minimumFractionDigits: decimals ?? 0, maximumFractionDigits: decimals ?? 0 }).format(n)
    case 'days': { const d = Math.round(n); return d === 1 ? '1 day' : `${d} days` }
    case 'date': return null
    default: {
      const digits = decimals ?? (n === Math.round(n) || Math.abs(n) >= 100 ? 0 : 1)
      const text = new Intl.NumberFormat(locale, { minimumFractionDigits: digits, maximumFractionDigits: digits }).format(n)
      return unit ? `${text} ${unit}` : text
    }
  }
}

/** A piece of a sentence: plain words, or a figure the calculations filled in. */
export type SentencePart = { text: string; figure: boolean }

/** A sentence as pieces, so a client can set its figures apart from its words; null while any figure it needs is unknown. */
export function sentenceParts(text: string, slots: Record<string, Slot>, data: KitData, locale?: string): SentencePart[] | null {
  const parts: SentencePart[] = []
  let cursor = 0
  for (const match of text.matchAll(/\{([a-z][a-z0-9_]{0,31})\}/g)) {
    const slot = slots[match[1]]
    if (!slot) return null
    const printed = formatKitValue(evaluate(slot.calc, data), slot.format, slot.unit, slot.decimals, locale)
    if (printed == null) return null
    if (match.index > cursor) parts.push({ text: text.slice(cursor, match.index), figure: false })
    parts.push({ text: printed, figure: true })
    cursor = match.index + match[0].length
  }
  if (cursor < text.length) parts.push({ text: text.slice(cursor), figure: false })
  return parts
}

/** A sentence with every {name} filled in, or null while any figure it needs is unknown. */
export function sentence(text: string, slots: Record<string, Slot>, data: KitData, locale?: string): string | null {
  return sentenceParts(text, slots, data, locale)?.map((p) => p.text).join('') ?? null
}

/** Every metric a calculation reads. */
export function calcMetrics(calc: Calc): string[] {
  return [...(calc.metric ? [calc.metric] : []), ...(calc.args ?? []).flatMap(calcMetrics)]
}
