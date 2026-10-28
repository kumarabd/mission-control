import type { InputHTMLAttributes, ReactNode, TextareaHTMLAttributes } from 'react'
import { forwardRef, useId } from 'react'
import { cn } from '../../lib/cn'

export function Field({
  label,
  hint,
  error,
  required,
  htmlFor,
  children,
  className,
}: {
  label?: ReactNode
  hint?: ReactNode
  error?: ReactNode
  required?: boolean
  htmlFor?: string
  children: ReactNode
  className?: string
}) {
  return (
    <div className={cn('flex flex-col gap-1.5', className)}>
      {label && (
        <label htmlFor={htmlFor} className="text-sm font-medium text-flat-foreground">
          {label}
          {required && <span className="ml-0.5 text-flat-danger">*</span>}
        </label>
      )}
      {children}
      {error ? (
        <p className="text-xs text-flat-danger">{error}</p>
      ) : (
        hint && <p className="text-xs text-flat-muted-fg">{hint}</p>
      )}
    </div>
  )
}

const fieldBase =
  'w-full rounded-sm border border-flat-border bg-flat-surface text-flat-foreground ' +
  'placeholder:text-flat-subtle-fg transition-colors duration-[var(--duration-instant)] ' +
  'focus:border-flat-primary focus:outline-none focus:ring-2 focus:ring-flat-primary/25 ' +
  'disabled:cursor-not-allowed disabled:opacity-60'

type Size = 'sm' | 'md' | 'native'
const inputSizes: Record<Size, string> = {
  sm: 'h-8 text-sm',
  md: 'h-9 text-base',
  /** Native 44px touch target. */
  native: 'h-11 text-native-body',
}

export type InputProps = InputHTMLAttributes<HTMLInputElement> & {
  iconLeft?: ReactNode
  iconRight?: ReactNode
  invalid?: boolean
  inputSize?: Size
}

export const Input = forwardRef<HTMLInputElement, InputProps>(function Input(
  { iconLeft, iconRight, invalid, inputSize = 'md', className, ...props },
  ref,
) {
  const id = useId()
  const field = (
    <input
      ref={ref}
      id={props.id ?? id}
      aria-invalid={invalid || undefined}
      className={cn(
        fieldBase,
        inputSizes[inputSize],
        iconLeft ? 'pl-8 pr-3' : 'px-3',
        iconRight ? 'pr-8' : '',
        invalid && 'border-flat-danger focus:border-flat-danger focus:ring-flat-danger/25',
        className,
      )}
      {...props}
    />
  )
  if (!iconLeft && !iconRight) return field
  return (
    <div className="relative">
      {iconLeft && (
        <span className="pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 text-flat-subtle-fg [&_svg]:size-4">
          {iconLeft}
        </span>
      )}
      {field}
      {iconRight && (
        <span className="absolute right-2.5 top-1/2 -translate-y-1/2 text-flat-subtle-fg [&_svg]:size-4">
          {iconRight}
        </span>
      )}
    </div>
  )
})

export type TextareaProps = TextareaHTMLAttributes<HTMLTextAreaElement> & { invalid?: boolean }

export const Textarea = forwardRef<HTMLTextAreaElement, TextareaProps>(function Textarea(
  { invalid, className, rows = 4, ...props },
  ref,
) {
  return (
    <textarea
      ref={ref}
      rows={rows}
      aria-invalid={invalid || undefined}
      className={cn(
        fieldBase,
        'resize-y px-3 py-2 text-base leading-relaxed',
        invalid && 'border-flat-danger focus:border-flat-danger focus:ring-flat-danger/25',
        className,
      )}
      {...props}
    />
  )
})

export default Input
