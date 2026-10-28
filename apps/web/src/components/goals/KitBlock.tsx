import { useState } from 'react'
import { CalendarDays, Check, ChevronRight, Circle, ExternalLink, Flag, Target, TriangleAlert, Undo2 } from 'lucide-react'
import { cn } from '../../lib/cn'
import {
  bucketed,
  calcMetrics,
  dayIndex,
  evaluate,
  formatDateTime,
  formatKitValue,
  knownBlock,
  observationsFor,
  periodStart,
  safeLinkUrl,
  sentenceParts,
  useCompleteTask,
  useGoalItems,
  type Calc,
  type Goal,
  type KitData,
  type KitLoad,
  type Measurement,
  type Point,
  type Step,
  type ViewBlock,
  type ViewMetric,
  type ViewState,
} from '../../lib/life'
import { Button } from '../ui'
import InlineError from '../mission/InlineError'
import ProgressBar from '../mission/ProgressBar'

export type KitActions = {
  onRetry: () => void
  onCheckIn: (metric: ViewMetric, measurement: Measurement | null) => void
  onStep: (step: Step) => void
  /** Record (+1) or take back (-1) one on a day, for a metric that reads a routine's logs. */
  onLogDay: (metric: ViewMetric, day: Date, delta: number) => void
  /** Record one number for a metric the person logs by hand; resolves to a message when it could not be saved. */
  onRecord: (metric: ViewMetric, value: number) => Promise<string | null>
}

/**
 * One block of a view. The kit is finite and says nothing about kinds of goal: the same few blocks, composed by the
 * assistant for the goal in front of it, draw a spending limit, a weigh-in or a habit. Each is built to be touched:
 * charts scrub (pointer or arrow keys), the bar and the grid answer a click, a routine's days can be logged where they
 * are drawn, and every motion has a still alternative.
 */
export default function KitBlock({
  block,
  view,
  state,
  goal,
  data,
  loads,
  index = 0,
  actions,
}: {
  block: ViewBlock
  view: NonNullable<ViewState['view']>
  state: ViewState
  goal: Goal
  data: KitData
  loads: Record<string, KitLoad>
  index?: number
  actions: KitActions
}) {
  const needs = blockMetrics(block)
  const failed = needs.map((id) => loads[id]).find((l) => l?.status === 'error')
  const waiting = needs.some((id) => loads[id]?.status === 'pending')
  const hero = block.kind === 'sentence' && block.emphasis === 'hero'
  const rise = { '--kit-delay': `${Math.min(index, 6) * 60}ms` } as React.CSSProperties

  if (!knownBlock(view, block)) {
    return (
      <Card block={block} rise={rise}>
        <p className="flex items-center gap-2 text-native-callout text-flat-muted-fg">
          <Target className="size-4 shrink-0" aria-hidden />
          This version of the app can’t show this block yet.
        </p>
      </Card>
    )
  }

  if (block.kind === 'sentence' || block.kind === 'text') {
    const parts = block.kind === 'sentence' && block.text ? sentenceParts(block.text, block.slots ?? {}, data) : null
    return (
      <div className={cn('kit-rise flex flex-col gap-1', hero && 'md:col-span-2')} style={rise}>
        {block.title && !hero && <h2 className="text-native-callout font-medium text-flat-foreground">{block.title}</h2>}
        {block.kind === 'text' ? (
          <>
            <p className="text-native-callout text-flat-muted-fg">{block.body}</p>
            {block.points && block.points.length > 0 && (
              <ul className="mt-1 flex flex-col gap-1.5">
                {block.points.map((point) => (
                  <li key={point} className="flex items-baseline gap-2 text-native-callout text-flat-foreground">
                    <span aria-hidden className="size-1.5 shrink-0 translate-y-[-1px] rounded-full bg-flat-primary" />
                    {point}
                  </li>
                ))}
              </ul>
            )}
          </>
        ) : parts ? (
          <p
            // Keyed on the words so a figure that changes lands with a small rise.
            key={parts.map((p) => p.text).join('')}
            aria-label={parts.map((p) => p.text).join('')}
            className={cn('kit-rise leading-tight tracking-tight text-flat-foreground', hero ? 'text-3xl font-semibold md:text-5xl' : 'text-lg font-medium')}
          >
            {parts.map((part, i) => (
              <span key={i} className={cn(part.figure && 'font-bold tabular-nums text-flat-primary')} aria-hidden>
                {part.text}
              </span>
            ))}
          </p>
        ) : failed ? (
          <InlineError title="Couldn’t read the data for this" description={failed.message} onRetry={actions.onRetry} />
        ) : (
          <p className="text-native-callout text-flat-muted-fg">{waiting ? 'Loading…' : 'Waiting for the numbers this needs.'}</p>
        )}
      </div>
    )
  }

  return (
    <Card block={block} rise={rise}>
      {failed ? (
        <InlineError title="Couldn’t read the data for this" description={failed.message} onRetry={actions.onRetry} />
      ) : waiting ? (
        <div className="flex flex-col gap-2" aria-busy="true" aria-label="Loading">
          <div className="h-3.5 w-32 animate-pulse rounded bg-flat-muted motion-reduce:animate-none" />
          <div className="h-20 animate-pulse rounded-xl bg-flat-muted motion-reduce:animate-none" />
        </div>
      ) : block.kind === 'bar' ? (
        <BarBlock block={block} data={data} />
      ) : block.kind === 'series' ? (
        <SeriesBlock block={block} data={data} />
      ) : block.kind === 'grid' ? (
        <GridBlock block={block} data={data} metric={view.metrics.find((m) => m.id === block.metric)} actions={actions} />
      ) : block.kind === 'steps' ? (
        <StepsBlock block={block} data={data} goal={goal} onStep={actions.onStep} />
      ) : block.kind === 'timeline' ? (
        <TimelineBlock block={block} data={data} />
      ) : block.kind === 'tasks' ? (
        <GoalItemsBlock goal={goal} kind="task" />
      ) : block.kind === 'events' ? (
        <GoalItemsBlock goal={goal} kind="event" />
      ) : block.kind === 'log' ? (
        <LogBlock block={block} view={view} state={state} actions={actions} />
      ) : block.kind === 'link' ? (
        <LinkBlock block={block} />
      ) : null}
    </Card>
  )
}

function Card({ block, rise, children }: { block: ViewBlock; rise: React.CSSProperties; children: React.ReactNode }) {
  const compact = block.emphasis === 'compact'
  return (
    <section aria-label={block.title ?? undefined} style={rise} className={cn('kit-rise rounded-2xl border border-flat-border bg-flat-surface', compact ? 'p-3' : 'p-4')}>
      {block.title && <h2 className={cn('font-medium text-flat-foreground', compact ? 'mb-2 text-sm' : 'mb-3 text-native-callout')}>{block.title}</h2>}
      {children}
    </section>
  )
}

/** Every metric a block depends on, in any of its calculations. */
function blockMetrics(block: ViewBlock): string[] {
  const calcs: (Calc | null | undefined)[] = [block.value, block.of, block.projection, block.trend_to, block.band?.from, block.band?.to]
  for (const m of [...(block.markers ?? []), ...(block.lines ?? [])]) calcs.push(m.at)
  for (const slot of Object.values(block.slots ?? {})) calcs.push(slot.calc)
  const ids = new Set<string>(block.metric ? [block.metric] : [])
  for (const calc of calcs) if (calc) calcMetrics(calc).forEach((id) => ids.add(id))
  return [...ids]
}

const num = (calc: Calc | null | undefined, data: KitData): number | null => {
  const v = calc ? evaluate(calc, data) : null
  return typeof v === 'number' ? v : null
}
const fmt = (n: number, block: ViewBlock) => formatKitValue(n, block.format, block.unit, block.decimals) ?? ''
const waitingText = <p className="text-native-callout text-flat-muted-fg">Waiting for the numbers this needs.</p>
const shortDate = (d: Date) => new Intl.DateTimeFormat(undefined, { weekday: 'short', month: 'short', day: 'numeric' }).format(d)
/** The local date for a day number (see dayIndex). */
const dateOf = (index: number) => new Date(1970, 0, 1 + index)

// Bar: how far a value has got along a scale. The fill grows in, marks are named on the bar, and a click reads it out.
function BarBlock({ block, data }: { block: ViewBlock; data: KitData }) {
  const [picked, setPicked] = useState(false)
  const value = num(block.value, data), full = num(block.of, data)
  if (value == null || full == null || full <= 0) return waitingText
  const projection = num(block.projection, data)
  const pct = (n: number) => `${Math.min(Math.max(n / full, 0), 1) * 100}%`
  const marks = (block.markers ?? []).flatMap((m) => { const at = num(m.at, data); return at == null ? [] : [{ label: m.label, at }] })
  const notes = [...marks.map((m) => `${m.label} ${fmt(m.at, block)}`), ...(projection != null && projection > value ? [`likely ${fmt(projection, block)}`] : [])]
  const percent = Math.round(Math.min(value / full, 9.99) * 100)
  return (
    <div className="flex flex-col gap-2">
      <button
        type="button"
        onClick={() => setPicked((p) => !p)}
        aria-pressed={picked}
        aria-label={`${block.title ?? 'Progress'}: ${fmt(value, block)} of ${fmt(full, block)}, ${percent} percent`}
        className="relative mt-5 block h-4 w-full cursor-pointer rounded-full bg-flat-muted text-left focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-flat-primary"
      >
        {projection != null && projection > value && (
          <span className="kit-grow-x absolute inset-y-0 left-0 rounded-full bg-flat-primary/30" style={{ width: pct(projection) }} />
        )}
        <span className="kit-grow-x absolute inset-y-0 left-0 rounded-full bg-flat-primary" style={{ width: pct(value) }} />
        {marks.map((m, i) => (
          <span key={i} className="absolute bottom-0 flex -translate-x-1/2 flex-col items-center" style={{ left: `clamp(24px, ${pct(m.at)}, calc(100% - 24px))` }} aria-hidden>
            <span className="mb-0.5 whitespace-nowrap font-mono text-2xs text-flat-muted-fg">{m.label}</span>
            <span className="-mb-1 h-7 w-0.5 bg-flat-foreground" />
          </span>
        ))}
      </button>
      <div className="flex items-baseline gap-2">
        <span className="text-xl font-semibold tabular-nums text-flat-foreground">{fmt(value, block)}</span>
        <span className="text-native-callout text-flat-muted-fg">of {fmt(full, block)}</span>
        <span className="ml-auto font-mono text-xs tabular-nums text-flat-muted-fg">{percent}%</span>
      </div>
      {notes.length > 0 && <p className={cn('font-mono text-2xs tabular-nums text-flat-muted-fg', picked && 'text-flat-foreground')}>{notes.join(' · ')}</p>}
    </div>
  )
}

// Series: one metric over time. Move along it (pointer or arrow keys) to read any point; it draws in, and says what changed.
function SeriesBlock({ block, data }: { block: ViewBlock; data: KitData }) {
  const [active, setActive] = useState<number | null>(null)
  const points = bucketed(block.metric ?? '', block.window, block.bucket, block.aggregate, data) ?? []
  if (points.length === 0) return <p className="text-native-callout text-flat-muted-fg">Nothing recorded in this range yet.</p>
  const style = block.style ?? 'line'
  const target = num(block.trend_to, data)
  const eta = block.trend_to && block.metric ? evaluate({ fn: 'eta', metric: block.metric, args: [block.trend_to] }, data) : null
  const trend = target != null && eta instanceof Date ? { x: dayIndex(eta), y: target } : null
  const band = block.band ? { from: num(block.band.from, data), to: num(block.band.to, data), label: block.band.label } : null
  const lines = (block.lines ?? []).flatMap((l) => { const y = num(l.at, data); return y == null ? [] : [{ y, label: l.label }] })

  const xs = points.map((p) => dayIndex(p.date))
  const step = xs.length > 1 ? Math.max(1, Math.min(...xs.slice(1).map((x, i) => x - xs[i]))) : 1
  const xMin = Math.min(...xs) - (style === 'bars' ? step / 2 : 0)
  const xMax = Math.max(...xs, trend?.x ?? -Infinity) + (style === 'bars' ? step / 2 : 0)
  const ys = [...points.map((p) => p.value), ...lines.map((l) => l.y), ...(band?.from != null ? [band.from] : []), ...(band?.to != null ? [band.to] : []), ...(trend ? [trend.y] : []), ...(style === 'bars' ? [0] : [])]
  const lo = Math.min(...ys), hi = Math.max(...ys), pad = (hi - lo || 1) * 0.08
  const yMin = lo - (style === 'bars' ? 0 : pad), yMax = hi + pad

  const W = 320, H = 176, L = 40, R = 8, T = 14, B = 22
  const X = (x: number) => L + ((x - xMin) / (xMax - xMin || 1)) * (W - L - R)
  const Y = (y: number) => T + (1 - (y - yMin) / (yMax - yMin || 1)) * (H - T - B)
  const last = points[points.length - 1], first = points[0]
  const picked: Point | null = active != null ? points[active] ?? null : null
  const short = (d: Date) => new Intl.DateTimeFormat(undefined, { month: 'short', day: 'numeric' }).format(d)
  const ticks = [lo, (lo + hi) / 2, hi]
  const barWidth = Math.max(2, ((W - L - R) / Math.max(xMax - xMin, 1)) * step * 0.7)
  const nearest = (clientX: number, el: SVGSVGElement) => {
    const box = el.getBoundingClientRect()
    const x = ((clientX - box.left) / box.width) * W
    let best = 0
    for (let i = 1; i < points.length; i += 1) if (Math.abs(X(xs[i]) - x) < Math.abs(X(xs[best]) - x)) best = i
    return best
  }
  const change = last.value - first.value
  const total = points.reduce((a, p) => a + p.value, 0)
  const readout = picked
    ? `${fmt(picked.value, block)} · ${shortDate(picked.date)}`
    : style === 'bars'
      ? `${fmt(total, block)} over ${points.length} ${block.bucket ?? 'day'}${points.length === 1 ? '' : 's'}`
      : points.length > 1 && change !== 0
        ? `${fmt(last.value, block)} · ${change < 0 ? '▼' : '▲'} ${fmt(Math.abs(change), block)} since ${short(first.date)}`
        : fmt(last.value, block)
  const linePath = points.map((p, i) => `${i === 0 ? 'M' : 'L'}${X(xs[i]).toFixed(1)},${Y(p.value).toFixed(1)}`).join(' ')

  return (
    <div className="flex flex-col gap-2">
      <p className="font-mono text-sm tabular-nums text-flat-foreground" aria-live="polite">{readout}</p>
      <svg
        viewBox={`0 0 ${W} ${H}`}
        className="h-auto w-full touch-pan-y text-flat-primary focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-flat-primary"
        role="img"
        tabIndex={0}
        aria-label={`${block.title ?? 'Chart'}: ${points.length} values, from ${fmt(first.value, block)} to ${fmt(last.value, block)}. Use the arrow keys to read each value.`}
        onPointerMove={(e) => setActive(nearest(e.clientX, e.currentTarget))}
        onPointerDown={(e) => setActive(nearest(e.clientX, e.currentTarget))}
        onPointerLeave={(e) => { if (e.pointerType === 'mouse') setActive(null) }}
        onBlur={() => setActive(null)}
        onKeyDown={(e) => {
          if (e.key === 'ArrowLeft') { e.preventDefault(); setActive((a) => Math.max(0, (a ?? points.length) - 1)) }
          else if (e.key === 'ArrowRight') { e.preventDefault(); setActive((a) => Math.min(points.length - 1, (a ?? -1) + 1)) }
          else if (e.key === 'Escape') setActive(null)
        }}
      >
        {ticks.map((t, i) => (
          <g key={i}>
            <line x1={L} x2={W - R} y1={Y(t)} y2={Y(t)} className="stroke-flat-border" strokeWidth={0.6} />
            <text x={L - 4} y={Y(t) + 3} textAnchor="end" className="fill-flat-muted-fg font-mono" fontSize={9}>{formatKitValue(t, block.format, null, block.decimals ?? (hi - lo < 10 ? 1 : 0))}</text>
          </g>
        ))}
        {band && band.from != null && band.to != null && (
          <>
            <rect x={L} y={Y(Math.max(band.from, band.to))} width={W - L - R} height={Math.abs(Y(band.from) - Y(band.to))} className="kit-fade fill-flat-primary/15" />
            <text x={L + 4} y={Y(Math.min(band.from, band.to)) - 3} className="fill-flat-foreground font-mono" fontSize={9}>{band.label}</text>
          </>
        )}
        {lines.map((l, i) => (
          <g key={i}>
            <line x1={L} x2={W - R} y1={Y(l.y)} y2={Y(l.y)} className="stroke-flat-foreground" strokeWidth={1} strokeDasharray="3 3" />
            <text x={W - R} y={Y(l.y) - 3} textAnchor="end" className="fill-flat-muted-fg font-mono" fontSize={9}>{l.label}</text>
          </g>
        ))}
        {style === 'bars' &&
          points.map((p, i) => (
            <rect key={i} className="kit-grow-y" style={{ '--kit-delay': `${Math.min(i, 30) * 18}ms` } as React.CSSProperties}
              x={X(xs[i]) - barWidth / 2} y={Y(p.value)} width={barWidth} height={Math.max(Y(0) - Y(p.value), 1)} rx={2}
              fill={active === i ? 'var(--color-flat-foreground)' : 'currentColor'} />
          ))}
        {style === 'line' && (
          <>
            <defs><linearGradient id="kit-area" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="var(--color-flat-primary)" stopOpacity="0.28" /><stop offset="1" stopColor="var(--color-flat-primary)" stopOpacity="0" /></linearGradient></defs>
            <path className="kit-fade" fill="url(#kit-area)" d={`${linePath} L${X(xs[xs.length - 1]).toFixed(1)},${Y(yMin).toFixed(1)} L${X(xs[0]).toFixed(1)},${Y(yMin).toFixed(1)} Z`} />
            <path className="kit-draw" pathLength={1} d={linePath} fill="none" stroke="currentColor" strokeWidth={2.4} strokeLinejoin="round" strokeLinecap="round" />
          </>
        )}
        {style !== 'bars' && points.map((p, i) => <circle key={i} cx={X(xs[i])} cy={Y(p.value)} r={style === 'dots' ? 3.5 : i === points.length - 1 ? 5 : 2.4} fill="currentColor" />)}
        {trend && <line className="kit-fade" x1={X(xs[xs.length - 1])} y1={Y(last.value)} x2={X(trend.x)} y2={Y(trend.y)} stroke="currentColor" strokeWidth={1.8} strokeDasharray="4 4" />}
        {picked && active != null && (
          <g>
            <line x1={X(xs[active])} x2={X(xs[active])} y1={T} y2={H - B} className="stroke-flat-foreground" strokeOpacity={0.35} strokeWidth={1} />
            <circle cx={X(xs[active])} cy={Y(picked.value)} r={5} className="fill-flat-foreground" />
          </g>
        )}
        <text x={L} y={H - 6} className="fill-flat-muted-fg font-mono" fontSize={9}>{short(first.date)}</text>
        <text x={W - R} y={H - 6} textAnchor="end" className="fill-flat-muted-fg font-mono" fontSize={9}>{short(trend && eta instanceof Date ? eta : last.date)}</text>
      </svg>
    </div>
  )
}

// Grid: which days something happened. For a routine, pick a day to record it there, and take one back.
function GridBlock({ block, data, metric, actions }: { block: ViewBlock; data: KitData; metric: ViewMetric | undefined; actions: KitActions }) {
  const [picked, setPicked] = useState<number | null>(null)
  const counts = new Map<number, number>()
  for (const p of data.series[block.metric ?? ''] ?? []) counts.set(dayIndex(p.date), (counts.get(dayIndex(p.date)) ?? 0) + p.value)
  const today = dayIndex(data.now)
  const ring = block.layout === 'week_row'
  const weeks = ring ? 1 : Math.min(Math.max(block.weeks ?? 5, 1), 12)
  const first = periodStart('week', data.now) - 7 * (weeks - 1)
  const days = Array.from({ length: weeks * 7 }, (_, i) => first + i)
  const weekday = (i: number) => new Intl.DateTimeFormat(undefined, { weekday: 'narrow' }).format(new Date(2024, 0, 1 + i)) // 1 Jan 2024 is a Monday
  const logs = Boolean(metric?.routine_id)
  const doneCount = days.filter((d) => (counts.get(d) ?? 0) > 0).length
  const elapsed = days.filter((d) => d <= today).length
  const value = picked != null ? counts.get(picked) ?? 0 : 0
  const pickedDate = picked != null ? dateOf(picked) : null
  return (
    <div className="flex flex-col gap-2">
      <div className={cn('grid grid-cols-7 text-center font-mono text-2xs text-flat-muted-fg', ring ? 'gap-1.5' : 'gap-1')} aria-hidden>
        {Array.from({ length: 7 }, (_, i) => <span key={i}>{weekday(i)}</span>)}
      </div>
      <div className={cn('grid grid-cols-7', ring ? 'gap-1.5' : 'gap-1')}>
        {days.map((day, n) => {
          const isDone = (counts.get(day) ?? 0) > 0, future = day > today, isToday = day === today
          const label = `${shortDate(dateOf(day))}, ${isDone ? 'done' : future ? 'not yet' : 'not done'}`
          const face = ring
            ? cn('flex aspect-square items-center justify-center rounded-full transition-transform active:scale-95',
                isDone ? 'bg-flat-primary text-flat-on-accent' : future ? 'border border-dashed border-flat-border-strong' : isToday ? 'border-2 border-flat-primary' : 'bg-flat-muted')
            : cn('aspect-[2/1] rounded-md transition-transform active:scale-95',
                isDone ? 'bg-flat-primary' : future ? 'border border-dashed border-flat-border-strong' : 'bg-flat-muted', isToday && !isDone && 'ring-2 ring-flat-primary')
          return (
            <button key={day} type="button" disabled={future} aria-label={label} aria-pressed={picked === day}
              onClick={() => setPicked((p) => (p === day ? null : day))}
              className={cn(face, 'kit-rise focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-flat-primary focus-visible:ring-offset-1', picked === day && 'ring-2 ring-flat-foreground', !future && 'cursor-pointer')}
              style={{ '--kit-delay': `${Math.min(n, 40) * 10}ms` } as React.CSSProperties}>
              {ring && isDone && <Check className="size-1/2" aria-hidden />}
            </button>
          )
        })}
      </div>
      <div className="flex min-h-11 flex-wrap items-center gap-x-3 gap-y-1" aria-live="polite">
        {pickedDate ? (
          <>
            <span className="font-mono text-xs tabular-nums text-flat-foreground">{shortDate(pickedDate)} · {value > 0 ? value : 'nothing'}</span>
            {logs && metric && picked != null && picked <= today && (
              <span className="ml-auto flex gap-1.5">
                <Button size="touch" variant="secondary" onClick={() => actions.onLogDay(metric, pickedDate, 1)}>Record one</Button>
                {value > 0 && (
                  <Button size="touch" variant="ghost" iconLeft={<Undo2 className="size-4" aria-hidden />} onClick={() => actions.onLogDay(metric, pickedDate, -1)}>Take one back</Button>
                )}
              </span>
            )}
          </>
        ) : (
          <span className="font-mono text-2xs tabular-nums text-flat-muted-fg">{doneCount} of {elapsed} days{logs ? ' · pick a day to record it' : ''}</span>
        )}
      </div>
    </div>
  )
}

// Steps: the goal's own one-off steps, or a ladder of thresholds a value climbs.
function StepsBlock({ block, data, goal, onStep }: { block: ViewBlock; data: KitData; goal: Goal; onStep: (step: Step) => void }) {
  if (block.source === 'goal_steps') return <GoalSteps goal={goal} onStep={onStep} />
  const marks = block.thresholds ?? []
  const value = num(block.value, data)
  if (value == null || marks.length < 2) return waitingText
  const next = marks.find((m) => m > value)
  return (
    <div className="flex flex-col gap-2">
      <div className="flex items-end gap-1" role="img" aria-label={`${marks.filter((m) => value >= m).length} of ${marks.length} steps reached`}>
        {marks.map((upper, i) => {
          const lower = i === 0 ? 0 : marks[i - 1]
          const fraction = upper > lower ? Math.min(Math.max((value - lower) / (upper - lower), 0), 1) : 0
          return (
            <div key={i} className="flex min-w-0 flex-1 flex-col gap-1">
              <span className={cn('truncate text-xs font-semibold tabular-nums', fraction >= 1 ? 'text-flat-foreground' : 'text-flat-muted-fg')}>{fmt(upper, block)}</span>
              <div className="h-3 overflow-hidden rounded-full bg-flat-muted">
                <div className="kit-grow-x h-full rounded-full bg-flat-primary" style={{ width: `${fraction * 100}%` }} />
              </div>
            </div>
          )
        })}
      </div>
      <p className="font-mono text-2xs text-flat-muted-fg">{next != null ? `${fmt(next - value, block)} to the next step` : 'Every step reached'}</p>
    </div>
  )
}

function GoalSteps({ goal, onStep }: { goal: Goal; onStep: (step: Step) => void }) {
  const steps = goal.steps ?? []
  const done = steps.filter((step) => step.done_at).length
  if (!steps.length) {
    return (
      <p className="flex items-center gap-2 text-native-callout text-flat-muted-fg">
        <Flag className="size-4" aria-hidden />
        No steps yet
      </p>
    )
  }
  return (
    <div>
      <ProgressBar value={done} max={steps.length} label={`${done} of ${steps.length} steps done`} />
      <div className="mt-1 flex flex-col">
        {steps.map((step) => {
          const isDone = Boolean(step.done_at)
          return (
            <button
              key={step.id}
              type="button"
              onClick={() => onStep(step)}
              disabled={isDone}
              aria-label={`${step.title}, ${isDone ? 'done' : 'mark done'}`}
              className="flex min-h-11 items-center gap-3 border-t border-flat-border py-1.5 text-left transition-colors hover:bg-flat-muted/40 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-flat-primary"
            >
              <span className={cn('flex size-6 shrink-0 items-center justify-center rounded-full border transition-all duration-300', isDone ? 'border-flat-primary bg-flat-primary text-flat-on-accent' : 'border-flat-border-strong text-transparent')}>
                {isDone ? <Check className="size-3.5" aria-hidden /> : <Circle className="size-2" aria-hidden />}
              </span>
              <span className={cn('min-w-0 flex-1 text-native-callout', isDone ? 'text-flat-muted-fg line-through' : 'text-flat-foreground')}>{step.title}</span>
              <span className="font-mono text-2xs tabular-nums text-flat-muted-fg">{step.minutes} min</span>
            </button>
          )
        })}
      </div>
    </div>
  )
}

// Timeline: dated marks on a line from today.
function TimelineBlock({ block, data }: { block: ViewBlock; data: KitData }) {
  const marks = (block.markers ?? [])
    .flatMap((m) => { const d = evaluate(m.at, data); return d instanceof Date ? [{ label: m.label, date: d }] : [] })
    .sort((a, b) => a.date.getTime() - b.date.getTime())
  if (marks.length === 0) return waitingText
  const today = dayIndex(data.now), span = Math.max(dayIndex(marks[marks.length - 1].date) - today, 1)
  const at = (d: Date) => `${Math.min(Math.max((dayIndex(d) - today) / span, 0), 1) * 100}%`
  return (
    <div className="flex flex-col gap-3">
      <div className="relative my-2 h-2.5 rounded-full bg-flat-muted" aria-hidden>
        <div className="kit-grow-x absolute inset-0 rounded-full bg-flat-primary/35" />
        {marks.map((m, i) => <div key={i} className="absolute -top-2 h-6 w-0.5 -translate-x-1/2 bg-flat-foreground" style={{ left: at(m.date) }} />)}
        <div className="absolute -left-0.5 -top-1.5 size-4">
          <span className="kit-pulse absolute inset-0 rounded-full bg-flat-primary" />
          <span className="absolute inset-0 rounded-full bg-flat-primary" />
        </div>
      </div>
      <ul className="flex flex-col gap-1">
        {marks.map((m, i) => (
          <li key={i} className="flex items-baseline justify-between gap-3 text-native-callout">
            <span>{m.label}</span>
            <span className="font-mono text-2xs tabular-nums text-flat-muted-fg">
              {new Intl.DateTimeFormat(undefined, { day: 'numeric', month: 'short' }).format(m.date)} · {dayIndex(m.date) - today} day{dayIndex(m.date) - today === 1 ? '' : 's'}
            </span>
          </li>
        ))}
      </ul>
    </div>
  )
}

// Tasks or events linked to the goal: the clean-slate engine's own records, not separate steps or routines.
function GoalItemsBlock({ goal, kind }: { goal: Goal; kind: 'task' | 'event' }) {
  const items = useGoalItems(goal.id)
  const complete = useCompleteTask()
  if (items.isError) {
    return <p className="text-native-callout text-flat-muted-fg">These didn’t load.</p>
  }
  const linked = (items.data ?? []).filter((item) => item.kind === kind)
  if (linked.length === 0) {
    return (
      <p className="flex items-center gap-2 text-native-callout text-flat-muted-fg">
        <Flag className="size-4" aria-hidden />
        {items.isPending
          ? 'Loading…'
          : kind === 'task'
            ? 'No tasks serve this goal yet'
            : 'No events serve this goal yet'}
      </p>
    )
  }
  return (
    <div className="flex flex-col">
      {linked.map((item) => {
        const done = Boolean(item.done_at)
        return (
          <div key={item.id} className="flex min-h-14 items-center gap-3 border-t border-flat-border py-2 first:border-t-0">
            {kind === 'task' ? (
              <button
                type="button"
                aria-label={`${done ? 'Reopen' : 'Mark done'} ${item.title}`}
                disabled={complete.isPending && complete.variables?.item.id === item.id}
                onClick={() => complete.mutate({ item, done: !done })}
                className={cn(
                  'flex size-9 shrink-0 items-center justify-center rounded-full border transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-flat-primary disabled:opacity-40',
                  done
                    ? 'border-flat-primary bg-flat-primary text-flat-on-accent'
                    : 'border-flat-border-strong text-transparent hover:text-flat-primary',
                )}
              >
                <Check className="size-4" aria-hidden />
              </button>
            ) : (
              <span className="flex size-9 shrink-0 items-center justify-center text-flat-scheduled">
                <CalendarDays className="size-4" aria-hidden />
              </span>
            )}
            <div className="min-w-0 flex-1">
              <span
                className={cn(
                  'block truncate text-native-callout font-medium',
                  done ? 'text-flat-muted-fg line-through' : 'text-flat-foreground',
                )}
              >
                {item.title}
              </span>
              <span className="block text-2xs text-flat-muted-fg">
                {item.at ? formatDateTime(item.at) : 'No set time'}
                {item.recurrence ? ' · repeats' : ''}
              </span>
            </div>
          </div>
        )
      })}
    </div>
  )
}

// Log: a quick way to record one number, typed here; open a record to correct it.
function LogBlock({ block, view, state, actions }: { block: ViewBlock; view: NonNullable<ViewState['view']>; state: ViewState; actions: KitActions }) {
  const metric = view.metrics.find((m) => m.id === block.metric)
  const [text, setText] = useState('')
  const [saving, setSaving] = useState(false)
  const [problem, setProblem] = useState<string | null>(null)
  if (!metric) return null
  const observations = observationsFor(state, metric.id)
  const value = Number(text)
  const valid = text.trim() !== '' && Number.isFinite(value) && (metric.minimum == null || value >= metric.minimum) && (metric.maximum == null || value <= metric.maximum)
  const save = async () => {
    setSaving(true)
    const message = await actions.onRecord(metric, value)
    setSaving(false)
    setProblem(message)
    if (!message) setText('')
  }
  return (
    <div className="flex flex-col gap-2">
      <form className="flex items-center gap-2" onSubmit={(e) => { e.preventDefault(); if (valid && !saving) void save() }}>
        <label className="sr-only" htmlFor={`log-${block.id}`}>{metric.label} in {metric.unit}</label>
        <input
          id={`log-${block.id}`} inputMode="decimal" autoComplete="off" value={text} onChange={(e) => setText(e.target.value)}
          placeholder={observations.length ? String(observations[observations.length - 1].value) : '0'}
          className="h-11 min-w-0 flex-1 rounded-xl border border-flat-border bg-flat-muted px-3 font-mono text-base tabular-nums text-flat-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-flat-primary"
        />
        <span className="text-native-callout text-flat-muted-fg">{metric.unit}</span>
        <Button type="submit" size="touch" disabled={!valid || saving}>Save</Button>
      </form>
      {problem && <p className="flex items-center gap-1.5 text-sm text-flat-critical"><TriangleAlert className="size-4" aria-hidden />{problem}</p>}
      {observations.length > 0 && (
        <details className="group">
          <summary className="flex min-h-11 cursor-pointer list-none items-center gap-2 text-native-callout text-flat-muted-fg marker:hidden hover:text-flat-foreground">
            <ChevronRight className="size-4 transition-transform group-open:rotate-90" aria-hidden />
            Recent records ({observations.length})
          </summary>
          <div className="flex flex-col">
            {observations.slice(-120).reverse().map((observation) => (
              <button key={observation.id} type="button" onClick={() => actions.onCheckIn(metric, observation)}
                className="flex min-h-11 items-center gap-2 border-t border-flat-border py-1.5 text-left hover:bg-flat-muted/50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-flat-primary">
                <span className="size-1.5 shrink-0 rounded-full bg-flat-primary" aria-hidden />
                <span className="min-w-0 flex-1">
                  <span className="block font-mono text-sm tabular-nums text-flat-foreground">{observation.value} {observation.unit || metric.unit}</span>
                  <span className="block text-2xs text-flat-muted-fg">{formatDateTime(observation.measured_at)}{observation.notes ? ` · ${observation.notes}` : ''}</span>
                </span>
                <ChevronRight className="size-4 text-flat-border-strong" aria-hidden />
              </button>
            ))}
          </div>
        </details>
      )}
    </div>
  )
}

function LinkBlock({ block }: { block: ViewBlock }) {
  const url = safeLinkUrl(block.url)
  if (!url) return null
  return (
    <a href={url} target="_blank" rel="noreferrer noopener" className="inline-flex min-h-11 items-center gap-2 text-native-callout text-flat-primary hover:underline">
      <ExternalLink className="size-4" aria-hidden />
      Open {new URL(url).host}
    </a>
  )
}
