import type { ButtonHTMLAttributes, ReactNode } from 'react'
import { cn } from '../../lib/cn'

type Props = ButtonHTMLAttributes<HTMLButtonElement> & {
  children: ReactNode
  tone?: 'neutral' | 'danger'
}

export default function ActionButton({
  children,
  tone = 'neutral',
  className,
  type = 'button',
  ...props
}: Props) {
  return (
    <button
      type={type}
      className={cn(
        'rounded-md px-2 py-1 text-sm font-semibold uppercase tracking-wider transition-all duration-200 hover:scale-105',
        'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-flat-primary focus-visible:ring-offset-2',
        tone === 'danger'
          ? 'text-flat-error hover:underline'
          : 'text-flat-primary hover:underline',
        'disabled:opacity-50 disabled:cursor-not-allowed',
        className,
      )}
      {...props}
    >
      {children}
    </button>
  )
}
