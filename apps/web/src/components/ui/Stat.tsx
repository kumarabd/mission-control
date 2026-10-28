import type { ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { ArrowDownRight, ArrowUpRight } from 'lucide-react'
import { cn } from '../../lib/cn'
import type { Tone } from './Badge'

export type StatProps = {
  label: string
  value: ReactNode
  hint?: ReactNode
  delta?: { value: number; direction: 'up' | 'down'; tone?: Tone }
  icon?: ReactNode
  href?: string
  className?: string
}

const deltaTone: Record<Tone, string> = {
  neutral: 'text-flat-muted-fg',
  accent: 'text-flat-primary',
  success: 'text-flat-success',
  warning: 'text-flat-warning',
  danger: 'text-flat-danger',
}

export default function Stat({ label, value, hint, delta, icon, href, className }: StatProps) {
  const body = (
    <>
      <div className="flex items-center justify-between gap-2">
        <span className="text-xs text-flat-muted-fg">{label}</span>
        {icon && <span className="text-flat-subtle-fg [&_svg]:size-4">{icon}</span>}
      </div>
      <div className="mt-1.5 flex items-baseline gap-2">
        <span className="font-mono text-2xl font-medium tracking-tight text-flat-foreground tabular-nums">
          {value}
        </span>
        {delta && (
          <span
            className={cn(
              'inline-flex items-center gap-0.5 text-xs font-medium',
              deltaTone[delta.tone ?? (delta.direction === 'up' ? 'success' : 'danger')],
            )}
          >
            {delta.direction === 'up' ? (
              <ArrowUpRight className="size-3" />
            ) : (
              <ArrowDownRight className="size-3" />
            )}
            {Math.abs(delta.value)}
          </span>
        )}
      </div>
      {hint && <div className="mt-1 text-xs text-flat-subtle-fg">{hint}</div>}
    </>
  )

  const cls = cn(
    'block rounded-md border border-flat-border bg-flat-surface p-3.5',
    href &&
      'transition-colors duration-[var(--duration-instant)] hover:border-flat-border-strong hover:bg-flat-surface-raised',
    className,
  )

  return href ? (
    <Link to={href} className={cls}>
      {body}
    </Link>
  ) : (
    <div className={cls}>{body}</div>
  )
}
