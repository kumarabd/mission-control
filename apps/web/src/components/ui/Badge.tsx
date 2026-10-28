import type { ReactNode } from 'react'
import { X } from 'lucide-react'
import { cn } from '../../lib/cn'

export type Tone = 'neutral' | 'accent' | 'success' | 'warning' | 'danger'
type Variant = 'soft' | 'solid' | 'outline'
/** @deprecated back-compat tone aliases from the old Badge. */
type LegacyTone = 'default' | 'gold' | 'midnight' | 'mint' | 'secondary'

type BadgeProps = {
  children: ReactNode
  tone?: Tone | LegacyTone
  /** fill style — also accepts a legacy tone name for back-compat */
  variant?: Variant | LegacyTone | Tone
  dot?: boolean
  className?: string
}

const FILL_VARIANTS = new Set<string>(['soft', 'solid', 'outline'])

const normalizeTone = (t: Tone | LegacyTone): Tone => {
  switch (t) {
    case 'gold':
    case 'midnight':
    case 'mint':
      return 'accent'
    case 'default':
    case 'secondary':
      return 'neutral'
    default:
      return t
  }
}

const soft: Record<Tone, string> = {
  neutral: 'bg-flat-muted text-flat-muted-fg',
  accent: 'bg-flat-tint text-flat-primary',
  success: 'bg-flat-success-muted text-flat-success',
  warning: 'bg-flat-warning-muted text-flat-warning',
  danger: 'bg-flat-danger-muted text-flat-danger',
}
const solid: Record<Tone, string> = {
  neutral: 'bg-flat-secondary text-flat-background',
  accent: 'bg-flat-primary text-flat-on-primary',
  success: 'bg-flat-success text-white',
  warning: 'bg-flat-warning text-white',
  danger: 'bg-flat-danger text-white',
}
const outline: Record<Tone, string> = {
  neutral: 'border border-flat-border text-flat-muted-fg',
  accent: 'border border-flat-primary/50 text-flat-primary',
  success: 'border border-flat-success/50 text-flat-success',
  warning: 'border border-flat-warning/50 text-flat-warning',
  danger: 'border border-flat-danger/50 text-flat-danger',
}
const dotColor: Record<Tone, string> = {
  neutral: 'bg-flat-subtle-fg',
  accent: 'bg-flat-primary',
  success: 'bg-flat-success',
  warning: 'bg-flat-warning',
  danger: 'bg-flat-danger',
}

export default function Badge({ children, tone, variant = 'soft', dot, className }: BadgeProps) {
  // Back-compat: old call sites passed the colour name as `variant`.
  const fill: Variant = FILL_VARIANTS.has(variant as string) ? (variant as Variant) : 'soft'
  const toneSource: Tone | LegacyTone =
    tone ?? (FILL_VARIANTS.has(variant as string) ? 'neutral' : (variant as LegacyTone))
  const t = normalizeTone(toneSource)
  const styles = fill === 'solid' ? solid : fill === 'outline' ? outline : soft
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1.5 rounded-xs px-2 py-0.5 text-2xs font-medium whitespace-nowrap',
        styles[t],
        className,
      )}
    >
      {dot && <span className={cn('h-1.5 w-1.5 shrink-0 rounded-full', dotColor[t])} aria-hidden />}
      {children}
    </span>
  )
}

type TagProps = {
  children: ReactNode
  /** explicit hex (e.g. a knowledge-graph category colour) */
  color?: string
  tone?: Tone
  onRemove?: () => void
  className?: string
}

export function Tag({ children, color, tone = 'neutral', onRemove, className }: TagProps) {
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1 rounded-xs border px-1.5 py-0.5 text-2xs font-medium',
        !color && soft[tone],
        !color && 'border-transparent',
        className,
      )}
      style={
        color
          ? { color, borderColor: `color-mix(in srgb, ${color} 40%, transparent)`, background: `color-mix(in srgb, ${color} 12%, transparent)` }
          : undefined
      }
    >
      {color && <span className="h-1.5 w-1.5 rounded-full" style={{ background: color }} aria-hidden />}
      {children}
      {onRemove && (
        <button
          type="button"
          onClick={onRemove}
          aria-label="Remove"
          className="-mr-0.5 ml-0.5 inline-flex size-3 items-center justify-center rounded-full hover:bg-flat-foreground/15"
        >
          <X className="size-2.5" />
        </button>
      )}
    </span>
  )
}
