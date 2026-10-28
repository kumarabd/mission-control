import { cn } from '../../lib/cn'
import { TONE, type MissionTone } from './tones'

export default function ProgressBar({
  value,
  max = 100,
  tone = 'focus',
  label,
  detail,
  className,
}: {
  value: number
  max?: number
  tone?: MissionTone
  label?: React.ReactNode
  detail?: React.ReactNode
  className?: string
}) {
  const pct = max > 0 ? Math.max(0, Math.min(100, (value / max) * 100)) : 0
  const t = TONE[tone]
  return (
    <div className={className}>
      <div className="h-2 overflow-hidden rounded-full bg-flat-muted">
        <div className={cn('h-full rounded-full transition-[width] duration-300', t.dot)} style={{ width: `${pct}%` }} />
      </div>
      {(label || detail) && (
        <div className="mt-1.5 flex items-baseline justify-between gap-3 text-xs text-flat-muted-fg">
          {label && <span className="min-w-0 truncate">{label}</span>}
          {detail && <span className="shrink-0 font-mono tabular-nums">{detail}</span>}
        </div>
      )}
    </div>
  )
}
