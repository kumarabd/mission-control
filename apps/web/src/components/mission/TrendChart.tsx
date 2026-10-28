import { cn } from '../../lib/cn'
import type { MissionTone } from './tones'
import { TONE } from './tones'

export type TrendPoint = { x: number; y: number; label?: string }

/** Small native-style SVG chart: no chart dependency, accessible label, target rule. */
export default function TrendChart({
  points,
  target,
  tone = 'focus',
  height = 132,
  ariaLabel,
  valueLabel,
  className,
}: {
  points: TrendPoint[]
  target?: number
  tone?: MissionTone
  height?: number
  ariaLabel: string
  valueLabel?: (v: number) => string
  className?: string
}) {
  const width = 320
  const pad = 10
  const values = points.map((p) => p.y)
  if (target != null) values.push(target)
  const min = values.length ? Math.min(...values) : 0
  const max = values.length ? Math.max(...values) : 1
  const span = max - min || 1
  const n = Math.max(points.length, 2)
  const xy = (p: TrendPoint, i: number) => {
    const x = pad + (i / (n - 1)) * (width - pad * 2)
    const y = height - pad - ((p.y - min) / span) * (height - pad * 2)
    return [x, y] as const
  }
  const coords = points.map(xy)
  const line = coords.map(([x, y], i) => `${i === 0 ? 'M' : 'L'}${x.toFixed(1)},${y.toFixed(1)}`).join(' ')
  const area = coords.length
    ? `${line} L${coords[coords.length - 1][0].toFixed(1)},${height - pad} L${coords[0][0].toFixed(1)},${height - pad} Z`
    : ''
  const targetY = target != null ? height - pad - ((target - min) / span) * (height - pad * 2) : null
  const t = TONE[tone]
  const last = points[points.length - 1]

  return (
    <div className={cn('w-full', className)}>
      <svg
        viewBox={`0 0 ${width} ${height}`}
        className={cn('h-auto w-full', t.text)}
        role="img"
        aria-label={ariaLabel}
      >
        {targetY != null && (
          <line
            x1={pad}
            x2={width - pad}
            y1={targetY}
            y2={targetY}
            stroke="currentColor"
            strokeWidth="1"
            strokeDasharray="4 5"
            className="opacity-35"
          />
        )}
        {area && <path d={area} fill="currentColor" className="opacity-[0.08]" />}
        {line && <path d={line} fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" />}
        {coords.length === 1 && <circle cx={coords[0][0]} cy={coords[0][1]} r="3.5" fill="currentColor" />}
      </svg>
      {last != null && (
        <div className="mt-1 flex items-baseline justify-between gap-3 text-xs text-flat-muted-fg">
          <span className="font-mono tabular-nums">{valueLabel ? valueLabel(last.y) : last.y}</span>
          <span>{last.label ?? 'Latest'}</span>
        </div>
      )}
    </div>
  )
}
