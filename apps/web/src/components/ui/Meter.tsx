/* eslint-disable react-refresh/only-export-components */
import { cn } from '../../lib/cn'
import type { Tone } from './Badge'

type MeterTone = Tone | 'accent' | 'neutral'

export function confidenceTone(v: number): Tone {
  if (v < 0.35) return 'danger'
  if (v < 0.6) return 'warning'
  if (v < 0.8) return 'neutral'
  return 'success'
}

const fill: Record<MeterTone, string> = {
  neutral: 'bg-flat-secondary',
  accent: 'bg-flat-primary',
  success: 'bg-flat-success',
  warning: 'bg-flat-warning',
  danger: 'bg-flat-danger',
}

export type MeterProps = {
  value: number
  max?: number
  label?: string
  showValue?: boolean
  tone?: MeterTone | ((v: number) => Tone)
  size?: 'sm' | 'md'
  className?: string
}

export default function Meter({
  value,
  max = 1,
  label,
  showValue,
  tone = 'accent',
  size = 'md',
  className,
}: MeterProps) {
  const ratio = Math.max(0, Math.min(1, max === 0 ? 0 : value / max))
  const resolved: MeterTone = typeof tone === 'function' ? tone(ratio) : tone
  const display = max === 1 ? ratio.toFixed(2) : String(value)
  return (
    <div className={cn('flex items-center gap-2', className)}>
      {label && <span className="shrink-0 text-xs text-flat-muted-fg">{label}</span>}
      <div
        role="meter"
        aria-valuenow={value}
        aria-valuemin={0}
        aria-valuemax={max}
        aria-label={label}
        className={cn(
          'min-w-0 flex-1 overflow-hidden rounded-full bg-flat-muted',
          size === 'sm' ? 'h-1' : 'h-1.5',
        )}
      >
        <div
          className={cn('h-full rounded-full transition-[width] duration-[var(--duration-base)]', fill[resolved])}
          style={{ width: `${ratio * 100}%` }}
        />
      </div>
      {showValue && (
        <span className="shrink-0 font-mono text-xs tabular-nums text-flat-muted-fg">{display}</span>
      )}
    </div>
  )
}
