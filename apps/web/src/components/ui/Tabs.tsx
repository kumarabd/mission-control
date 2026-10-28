import type { ReactNode } from 'react'
import { NavLink } from 'react-router-dom'
import { cn } from '../../lib/cn'

/* ---------- Tabs (underline, controlled) ---------- */

export type TabItem = { value: string; label: ReactNode; count?: number; disabled?: boolean }

export function Tabs({
  value,
  onValueChange,
  items,
  size = 'md',
  className,
}: {
  value: string
  onValueChange: (v: string) => void
  items: TabItem[]
  size?: 'sm' | 'md'
  className?: string
}) {
  return (
    <div role="tablist" className={cn('flex gap-4 border-b border-flat-border', className)}>
      {items.map((item) => {
        const active = item.value === value
        return (
          <button
            key={item.value}
            role="tab"
            type="button"
            aria-selected={active}
            disabled={item.disabled}
            onClick={() => onValueChange(item.value)}
            className={cn(
              '-mb-px flex items-center gap-1.5 border-b-2 pb-2.5 pt-1 font-medium transition-colors',
              size === 'sm' ? 'text-sm' : 'text-base',
              active
                ? 'border-flat-primary text-flat-foreground'
                : 'border-transparent text-flat-muted-fg hover:text-flat-foreground',
              item.disabled && 'pointer-events-none opacity-50',
            )}
          >
            {item.label}
            {item.count != null && (
              <span
                className={cn(
                  'rounded-full px-1.5 text-2xs font-medium tabular-nums',
                  active ? 'bg-flat-tint text-flat-primary' : 'bg-flat-muted text-flat-muted-fg',
                )}
              >
                {item.count}
              </span>
            )}
          </button>
        )
      })}
    </div>
  )
}

/* ---------- RoutedTabs (NavLink-based) ---------- */

export function RoutedTabs({
  items,
  className,
}: {
  items: { to: string; label: ReactNode; count?: number; end?: boolean }[]
  className?: string
}) {
  return (
    <div className={cn('flex gap-4 border-b border-flat-border', className)}>
      {items.map((item) => (
        <NavLink
          key={item.to}
          to={item.to}
          end={item.end}
          className={({ isActive }) =>
            cn(
              '-mb-px flex items-center gap-1.5 border-b-2 pb-2.5 pt-1 text-base font-medium no-underline transition-colors',
              isActive
                ? 'border-flat-primary text-flat-foreground'
                : 'border-transparent text-flat-muted-fg hover:text-flat-foreground hover:no-underline',
            )
          }
        >
          {item.label}
          {item.count != null && (
            <span className="rounded-full bg-flat-muted px-1.5 text-2xs tabular-nums text-flat-muted-fg">
              {item.count}
            </span>
          )}
        </NavLink>
      ))}
    </div>
  )
}

/* ---------- Segmented (true either/or) ---------- */

export function Segmented<T extends string>({
  value,
  onValueChange,
  options,
  size = 'md',
  fullWidth = false,
  className,
}: {
  value: T
  onValueChange: (v: T) => void
  options: { value: T; label: ReactNode; disabled?: boolean }[]
  size?: 'sm' | 'md'
  /** Native full-width segmented control, one 44px-tall row. */
  fullWidth?: boolean
  className?: string
}) {
  return (
    <div
      role="radiogroup"
      className={cn(
        'items-center gap-0.5 rounded-sm border border-flat-border bg-flat-muted p-0.5',
        fullWidth ? 'flex w-full' : 'inline-flex',
        className,
      )}
    >
      {options.map((opt) => {
        const active = opt.value === value
        return (
          <button
            key={opt.value}
            type="button"
            role="radio"
            aria-checked={active}
            disabled={opt.disabled}
            onClick={() => onValueChange(opt.value)}
            className={cn(
              'rounded-[3px] font-medium transition-colors',
              fullWidth
                ? 'h-11 flex-1 text-native-callout'
                : size === 'sm'
                  ? 'h-6 px-2 text-2xs'
                  : 'h-7 px-2.5 text-sm',
              active
                ? 'bg-flat-surface text-flat-foreground shadow-1'
                : 'text-flat-muted-fg hover:text-flat-foreground',
              opt.disabled && 'pointer-events-none opacity-40',
            )}
          >
            {opt.label}
          </button>
        )
      })}
    </div>
  )
}

/* ---------- Switch ---------- */

export function Switch({
  checked,
  onCheckedChange,
  label,
  disabled,
  className,
}: {
  checked: boolean
  onCheckedChange: (v: boolean) => void
  label?: ReactNode
  disabled?: boolean
  className?: string
}) {
  return (
    <label className={cn('inline-flex cursor-pointer items-center gap-2 text-sm text-flat-foreground', className)}>
      <button
        type="button"
        role="switch"
        aria-checked={checked}
        disabled={disabled}
        onClick={() => onCheckedChange(!checked)}
        className={cn(
          'relative h-4.5 w-8 shrink-0 rounded-full border transition-colors',
          checked ? 'border-flat-primary bg-flat-primary' : 'border-flat-border bg-flat-muted',
          disabled && 'opacity-50',
        )}
        style={{ height: 18, width: 32 }}
      >
        <span
          className={cn(
            'absolute left-0 top-0.5 size-3.5 rounded-full bg-flat-surface shadow-sm transition-transform',
            checked ? 'translate-x-[15px]' : 'translate-x-[2px]',
          )}
        />
      </button>
      {label}
    </label>
  )
}
