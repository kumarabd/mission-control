import type { ReactNode } from 'react'
import { cn } from '../../lib/cn'

export default function Kbd({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <kbd
      className={cn(
        'inline-flex h-5 min-w-5 items-center justify-center rounded-xs border border-flat-border bg-flat-muted px-1',
        'font-mono text-2xs font-medium text-flat-muted-fg',
        className,
      )}
    >
      {children}
    </kbd>
  )
}
