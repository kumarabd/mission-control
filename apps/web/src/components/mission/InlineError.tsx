import { AlertTriangle } from 'lucide-react'
import { Button } from '../ui'
import { cn } from '../../lib/cn'

/** A section-level failure with a retry, not a blank page. */
export default function InlineError({
  title = 'Some items couldn’t load',
  description,
  onRetry,
  className,
}: {
  title?: string
  description?: React.ReactNode
  onRetry?: () => void
  className?: string
}) {
  return (
    <div className={cn('rounded-2xl border border-flat-warning/30 bg-flat-warning-muted px-4 py-3.5', className)}>
      <div className="flex items-start gap-3">
        <AlertTriangle className="mt-0.5 size-5 shrink-0 text-flat-warning" aria-hidden />
        <div className="min-w-0 flex-1">
          <p className="text-native-callout font-medium text-flat-foreground">{title}</p>
          {description && <p className="mt-0.5 text-sm text-flat-muted-fg">{description}</p>}
        </div>
        {onRetry && (
          <Button variant="secondary" size="sm" onClick={onRetry}>
            Try again
          </Button>
        )}
      </div>
    </div>
  )
}
