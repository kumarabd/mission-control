import type { ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { cn } from '../../lib/cn'

type Props = {
  children: ReactNode
  to?: string
  variant?: 'warning' | 'info'
  className?: string
}

export default function AlertBanner({ children, to, variant = 'warning', className }: Props) {
  const classes = cn(
    'group block rounded-lg p-4 text-base font-medium',
    'transition-all duration-200 ease-out hover:scale-[1.02]',
    variant === 'warning'
      ? 'bg-flat-tint-warm text-flat-foreground'
      : 'bg-flat-tint text-flat-foreground',
    className,
  )

  if (to) {
    return (
      <Link to={to} className={cn(classes, 'no-underline')}>
        {children}
      </Link>
    )
  }

  return <div className={classes}>{children}</div>
}
