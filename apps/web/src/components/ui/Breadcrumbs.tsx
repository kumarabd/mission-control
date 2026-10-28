import type { ReactNode } from 'react'
import { Fragment } from 'react'
import { ChevronRight } from 'lucide-react'
import { Link } from 'react-router-dom'
import { cn } from '../../lib/cn'

export type Crumb = { label: ReactNode; to?: string }

export default function Breadcrumbs({ items, className }: { items: Crumb[]; className?: string }) {
  return (
    <nav aria-label="Breadcrumb" className={cn('flex min-w-0 items-center gap-1 text-sm', className)}>
      {items.map((crumb, i) => {
        const last = i === items.length - 1
        return (
          <Fragment key={i}>
            {i > 0 && (
              <ChevronRight
                className={cn('size-3.5 shrink-0 text-flat-subtle-fg', !last && 'hidden sm:block')}
              />
            )}
            {crumb.to && !last ? (
              <Link
                to={crumb.to}
                className={cn(
                  'hidden truncate text-flat-muted-fg no-underline hover:text-flat-foreground hover:no-underline sm:inline',
                )}
              >
                {crumb.label}
              </Link>
            ) : (
              <span
                className={cn(
                  'truncate',
                  last ? 'text-flat-foreground' : 'hidden text-flat-muted-fg sm:inline',
                )}
              >
                {crumb.label}
              </span>
            )}
          </Fragment>
        )
      })}
    </nav>
  )
}
