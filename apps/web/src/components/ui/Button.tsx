import type { ButtonHTMLAttributes, ReactNode } from 'react'
import { forwardRef } from 'react'
import { cn } from '../../lib/cn'

type Variant = 'primary' | 'secondary' | 'ghost' | 'outline' | 'danger'
/** @deprecated back-compat aliases; migrate to the 5 names above. */
type LegacyVariant = 'solid' | 'default'
type Size = 'sm' | 'md' | 'lg' | 'touch'

export type ButtonProps = Omit<ButtonHTMLAttributes<HTMLButtonElement>, 'children'> & {
  variant?: Variant | LegacyVariant
  size?: Size
  loading?: boolean
  iconLeft?: ReactNode
  iconRight?: ReactNode
  fullWidth?: boolean
  children: ReactNode
}

const base =
  'relative inline-flex items-center justify-center gap-2 rounded-sm font-medium ' +
  'transition-colors duration-[var(--duration-instant)] ease-[var(--ease-standard)] ' +
  'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-flat-primary focus-visible:ring-offset-2 focus-visible:ring-offset-flat-background ' +
  'disabled:pointer-events-none disabled:opacity-50'

const sizes: Record<Size, string> = {
  sm: 'h-8 px-2.5 text-sm',
  md: 'h-9 px-3.5 text-base',
  lg: 'h-10 px-4 text-base',
  /** Native 44px target. */
  touch: 'h-11 px-4 text-native-body',
}

const variants: Record<Variant | LegacyVariant, string> = {
  solid: 'bg-flat-primary text-flat-on-primary hover:bg-flat-primary-hover',
  default: 'bg-flat-primary text-flat-on-primary hover:bg-flat-primary-hover',
  primary: 'bg-flat-primary text-flat-on-primary hover:bg-flat-primary-hover',
  secondary:
    'bg-flat-muted text-flat-foreground hover:bg-flat-tint-soft border border-flat-border',
  ghost: 'bg-transparent text-flat-muted-fg hover:bg-flat-muted hover:text-flat-foreground',
  outline:
    'border border-flat-border-strong bg-transparent text-flat-foreground hover:bg-flat-muted',
  danger: 'bg-flat-danger text-white hover:brightness-110',
}

const Button = forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  {
    variant = 'secondary',
    size = 'md',
    loading = false,
    iconLeft,
    iconRight,
    fullWidth,
    className,
    children,
    type = 'button',
    disabled,
    ...props
  },
  ref,
) {
  return (
    <button
      ref={ref}
      type={type}
      disabled={disabled || loading}
      aria-busy={loading || undefined}
      className={cn(base, sizes[size], variants[variant], fullWidth && 'w-full', className)}
      {...props}
    >
      {loading && (
        <span
          aria-hidden
          className="absolute inline-block h-4 w-4 animate-spin rounded-full border-2 border-current border-t-transparent opacity-70"
        />
      )}
      <span className={cn('inline-flex items-center gap-2', loading && 'invisible')}>
        {iconLeft}
        {children}
        {iconRight}
      </span>
    </button>
  )
})

export default Button
