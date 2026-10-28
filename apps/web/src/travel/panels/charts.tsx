import type { CSSProperties } from 'react'
import type { DayStat } from '../api/journeys'
import { chartGeometry, formatMiles, formatReading } from '../utils/drives'
import { formatClock } from '../utils/format'

/** Distance driven per day. Empty days stay on the axis so gaps read as gaps; the bars grow in once, left to right. */
export function DistanceBars({ days }: { days: DayStat[] }) {
  const W = 320
  const H = 72
  const max = Math.max(...days.map((d) => d.distance_km), 0.001)
  const slot = W / Math.max(days.length, 1)
  const bar = Math.max(2, slot * 0.7)
  const label = (iso: string) => new Date(`${iso}T12:00:00`).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })

  return (
    <div>
      <svg viewBox={`0 0 ${W} ${H}`} className="h-20 w-full" role="img" aria-label={`Distance driven per day over the last ${days.length} days`}>
        {days.map((d, i) => {
          const h = d.distance_km > 0 ? Math.max(3, (d.distance_km / max) * (H - 6)) : 1.5
          return (
            <rect
              key={d.date}
              x={i * slot + (slot - bar) / 2}
              y={H - h}
              width={bar}
              height={h}
              rx={Math.min(2, bar / 2)}
              className={`travel-bar ${d.distance_km > 0 ? 'fill-flat-primary' : 'fill-flat-border'}`}
              style={{ '--i': i } as CSSProperties}
            >
              <title>{`${label(d.date)}: ${formatMiles(d.distance_km)}, ${d.journeys} ${d.journeys === 1 ? 'trip' : 'trips'}`}</title>
            </rect>
          )
        })}
      </svg>
      <div className="mt-1 flex justify-between text-xs text-flat-muted-fg">
        <span>{days.length ? label(days[0].date) : ''}</span>
        <span>Today</span>
      </div>
    </div>
  )
}

/** One sensor over a drive: a line with its range and the start and end times. */
export function SensorChart({ title, unit, points, loading }: { title: string; unit: string; points: { time: string; value: number }[]; loading?: boolean }) {
  const W = 320
  const H = 110
  const g = chartGeometry(points.map((p) => p.value), W, H, 6)
  const avg = points.length ? points.reduce((a, p) => a + p.value, 0) / points.length : 0
  const u = unit ? ` ${unit}` : ''
  return (
    <div className="rounded-md border border-flat-border p-3">
      <div className="flex items-baseline justify-between gap-2">
        <h3 className="truncate text-base font-medium text-flat-foreground">{title}</h3>
        {points.length > 0 && (
          <span className="shrink-0 text-sm tabular-nums text-flat-muted-fg">
            avg {formatReading(avg)}
            {u}
          </span>
        )}
      </div>
      {points.length === 0 ? (
        <p className="py-8 text-center text-sm text-flat-muted-fg">{loading ? 'Loading…' : 'No readings.'}</p>
      ) : (
        <>
          <svg viewBox={`0 0 ${W} ${H}`} className="mt-2 h-28 w-full" role="img" aria-label={`${title}: from ${formatReading(g.min)} to ${formatReading(g.max)}${u}`}>
            <path d={g.area} className="fill-flat-primary/10" />
            <path d={g.line} fill="none" strokeWidth={2} strokeLinejoin="round" className="stroke-flat-primary" />
          </svg>
          <div className="mt-1 flex justify-between text-xs tabular-nums text-flat-muted-fg">
            <span>{formatClock(new Date(points[0].time))}</span>
            <span>
              {formatReading(g.min)} – {formatReading(g.max)}
              {u}
            </span>
            <span>{formatClock(new Date(points[points.length - 1].time))}</span>
          </div>
        </>
      )}
    </div>
  )
}
