import type { ButtonHTMLAttributes, ReactNode } from 'react'
import { forwardRef } from 'react'
import { cn } from '../../lib/cn'

type Variant = 'ghost' | 'outline' | 'solid'
type Size = 'sm' | 'md' | 'lg'

export type IconButtonProps = Omit<ButtonHTMLAttributes<HTMLButtonElement>, 'children'> & {
  label: string
  variant?: Variant
  size?: Size
  loading?: boolean
  children: ReactNode
}

const sizes: Record<Size, string> = {
  sm: 'h-7 w-7 [&_svg]:size-3.5',
  md: 'h-8 w-8 [&_svg]:size-4',
  /** Native 44px target. */
  lg: 'h-11 w-11 [&_svg]:size-5',
}

const variants: Record<Variant, string> = {
  ghost: 'text-flat-muted-fg hover:bg-flat-muted hover:text-flat-foreground',
  outline:
    'border border-flat-border text-flat-muted-fg hover:bg-flat-muted hover:text-flat-foreground',
  solid: 'bg-flat-primary text-flat-on-primary hover:bg-flat-primary-hover',
}

const IconButton = forwardRef<HTMLButtonElement, IconButtonProps>(function IconButton(
  { label, variant = 'ghost', size = 'md', loading, className, children, type = 'button', disabled, ...props },
  ref,
) {
  return (
    <button
      ref={ref}
      type={type}
      aria-label={label}
      title={label}
      disabled={disabled || loading}
      className={cn(
        'inline-flex shrink-0 items-center justify-center rounded-sm transition-colors',
        'duration-[var(--duration-instant)] ease-[var(--ease-standard)]',
        'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-flat-primary focus-visible:ring-offset-2 focus-visible:ring-offset-flat-background',
        'disabled:pointer-events-none disabled:opacity-50',
        sizes[size],
        variants[variant],
        className,
      )}
      {...props}
    >
      {loading ? (
        <span
          aria-hidden
          className="inline-block h-3.5 w-3.5 animate-spin rounded-full border-2 border-current border-t-transparent opacity-70"
        />
      ) : (
        children
      )}
    </button>
  )
})

export default IconButton
