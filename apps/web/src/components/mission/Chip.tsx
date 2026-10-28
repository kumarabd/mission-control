import { Check } from 'lucide-react'
import type { LucideIcon } from 'lucide-react'
import { cn } from '../../lib/cn'

export default function Chip({
  selected,
  onClick,
  icon: Icon,
  children,
  className,
  disabled,
}: {
  selected?: boolean
  onClick?: () => void
  icon?: LucideIcon
  children: React.ReactNode
  className?: string
  disabled?: boolean
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      aria-pressed={selected}
      className={cn(
        'press inline-flex min-h-11 items-center gap-2 rounded-full border px-4 text-native-callout transition-colors',
        selected
          ? 'border-flat-primary bg-flat-tint text-flat-foreground'
          : 'border-flat-border bg-flat-surface text-flat-muted-fg hover:border-flat-primary hover:text-flat-foreground',
        disabled && 'pointer-events-none opacity-50',
        className,
      )}
    >
      {Icon && <Icon className="size-4 shrink-0" aria-hidden />}
      <span>{children}</span>
      {selected && <Check className="size-4 shrink-0 text-flat-primary" aria-hidden />}
    </button>
  )
}
