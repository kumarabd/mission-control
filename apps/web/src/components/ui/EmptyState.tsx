import type { ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { cn } from '../../lib/cn'
import Button from './Button'

type Action = { label: string; to?: string; onClick?: () => void }

type EmptyStateProps = {
  icon?: ReactNode
  title?: string
  body?: ReactNode
  action?: Action
  secondaryAction?: Action
  size?: 'sm' | 'md'
  className?: string
  /** @deprecated old API passed a bare sentence as children */
  children?: ReactNode
}

export default function EmptyState({
  icon,
  title,
  body,
  action,
  secondaryAction,
  size = 'md',
  className,
  children,
}: EmptyStateProps) {
  const resolvedTitle =
    title || (typeof children === 'string' || Array.isArray(children) ? children : 'Nothing here yet')
  const resolvedBody = body ?? (title ? children : undefined)
  return (
    <div
      className={cn(
        'flex flex-col items-center text-center',
        size === 'md' ? 'gap-3 px-6 py-14' : 'gap-2 px-4 py-8',
        className,
      )}
    >
      {icon && (
        <span className="flex size-10 items-center justify-center rounded-full bg-flat-muted text-flat-muted-fg [&_svg]:size-5">
          {icon}
        </span>
      )}
      <div>
        <p className={cn('text-flat-foreground', size === 'md' ? 'text-lg' : 'text-base font-medium')}>
          {resolvedTitle}
        </p>
        {resolvedBody && (
          <p className="mx-auto mt-1 max-w-sm text-sm text-flat-muted-fg">{resolvedBody}</p>
        )}
      </div>
      {(action || secondaryAction) && (
        <div className="mt-1 flex items-center gap-2">
          {action &&
            (action.to ? (
              <Link
                to={action.to}
                className="inline-flex h-8 items-center rounded-sm bg-flat-primary px-3.5 text-base font-medium text-flat-on-primary hover:bg-flat-primary-hover"
                onClick={action.onClick}
              >
                {action.label}
              </Link>
            ) : (
              <Button variant="primary" size="sm" onClick={action.onClick}>
                {action.label}
              </Button>
            ))}
          {secondaryAction &&
            (secondaryAction.to ? (
              <Link
                to={secondaryAction.to}
                className="inline-flex h-8 items-center rounded-sm px-3 text-base text-flat-muted-fg hover:text-flat-foreground"
                onClick={secondaryAction.onClick}
              >
                {secondaryAction.label}
              </Link>
            ) : (
              <Button variant="ghost" size="sm" onClick={secondaryAction.onClick}>
                {secondaryAction.label}
              </Button>
            ))}
        </div>
      )}
    </div>
  )
}
