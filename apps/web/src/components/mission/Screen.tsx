import type { ReactNode } from 'react'
import { cn } from '../../lib/cn'

/** Native page frame: mono eyebrow, 34px title, description, actions. */
export default function Screen({
  eyebrow,
  title,
  description,
  actions,
  children,
  className,
}: {
  eyebrow?: ReactNode
  title: ReactNode
  description?: ReactNode
  actions?: ReactNode
  children: ReactNode
  className?: string
}) {
  return (
    <div className={cn('pb-10', className)}>
      <header className="mb-6 flex flex-wrap items-end justify-between gap-4">
        <div className="min-w-0">
          {eyebrow && (
            <div className="mb-1.5 font-mono text-2xs uppercase tracking-[0.12em] text-flat-muted-fg">{eyebrow}</div>
          )}
          <h1 className="text-native-title text-flat-foreground">{title}</h1>
          {description && (
            <p className="mt-1.5 max-w-2xl text-native-callout text-flat-muted-fg">{description}</p>
          )}
        </div>
        {actions && <div className="ml-auto flex shrink-0 flex-wrap items-center gap-2">{actions}</div>}
      </header>
      {children}
    </div>
  )
}
