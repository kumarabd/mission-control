import type { ReactNode } from 'react'
import { cn } from '../../lib/cn'

type Props = {
  title: ReactNode
  description?: ReactNode
  actions?: ReactNode
  className?: string
}

/** The one page heading: a large, light title, a quiet description and optional actions. */
export default function PageHeader({ title, description, actions, className }: Props) {
  return (
    <header className={cn('mb-7', className)}>
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div className="max-w-2xl">
          <h1 className="text-[clamp(1.9rem,3.4vw,2.6rem)] font-normal leading-[1.08] tracking-[-0.03em] text-flat-foreground">
            {title}
          </h1>
          {description && <p className="mt-2 text-base text-flat-muted-fg">{description}</p>}
        </div>
        {actions && <div className="flex shrink-0 items-center gap-2">{actions}</div>}
      </div>
    </header>
  )
}
