import type { ElementType, HTMLAttributes, ReactNode } from 'react'
import { cn } from '../../lib/cn'

type Padding = 'none' | 'sm' | 'md'

type CardProps = HTMLAttributes<HTMLDivElement> & {
  as?: ElementType
  interactive?: boolean
  padding?: Padding
  elevation?: 0 | 1
  children: ReactNode
  /** @deprecated use `interactive` */
  hoverable?: boolean
  /** @deprecated */
  prominent?: boolean
}

const pad: Record<Padding, string> = { none: '', sm: 'p-3', md: 'p-4' }

export function Card({
  as: Tag = 'div',
  interactive,
  hoverable,
  prominent,
  padding = 'md',
  elevation = 0,
  className,
  children,
  ...props
}: CardProps) {
  const isInteractive = interactive ?? hoverable ?? false
  return (
    <Tag
      className={cn(
        'rounded-2xl border border-flat-border bg-flat-surface',
        elevation === 1 && 'shadow-1',
        pad[padding],
        isInteractive &&
          'cursor-pointer transition-colors duration-[var(--duration-instant)] ease-[var(--ease-standard)] hover:border-flat-border-strong hover:bg-flat-surface-raised',
        prominent && 'border-flat-primary/40 bg-flat-tint',
        className,
      )}
      {...props}
    >
      {children}
    </Tag>
  )
}

/** New API: structured header. */
export function CardHeader({
  title,
  description,
  actions,
  children,
  className,
  /** @deprecated legacy tint accent — ignored */
  accent: _accent,
}: {
  title?: ReactNode
  description?: ReactNode
  actions?: ReactNode
  children?: ReactNode
  className?: string
  accent?: string
}) {
  if (children && !title) {
    // legacy usage: <CardHeader><CardTitle/>…</CardHeader>
    return <div className={cn('mb-3', className)}>{children}</div>
  }
  return (
    <div className={cn('mb-3 flex items-start justify-between gap-3', className)}>
      <div className="min-w-0">
        {title && <h3 className="text-lg text-flat-foreground">{title}</h3>}
        {description && <p className="mt-0.5 text-sm text-flat-muted-fg">{description}</p>}
        {children}
      </div>
      {actions && <div className="flex shrink-0 items-center gap-2">{actions}</div>}
    </div>
  )
}

export function CardBody({ children, className }: { children: ReactNode; className?: string }) {
  return <div className={cn('text-base text-flat-foreground', className)}>{children}</div>
}

export function CardFooter({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <div className={cn('mt-3 flex items-center gap-2 border-t border-flat-border pt-3', className)}>
      {children}
    </div>
  )
}

/* ---- Back-compat sub-components (retired as pages are rebuilt) ---- */
export function CardTitle({ children, className }: { children: ReactNode; className?: string }) {
  return <h3 className={cn('text-lg text-flat-foreground', className)}>{children}</h3>
}
export function CardDescription({ children, className }: { children: ReactNode; className?: string }) {
  return <p className={cn('mt-0.5 text-sm text-flat-muted-fg', className)}>{children}</p>
}
export function CardContent({ children, className }: { children: ReactNode; className?: string }) {
  return <div className={cn('text-base text-flat-foreground', className)}>{children}</div>
}
