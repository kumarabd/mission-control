import { cn } from '../../lib/cn'

/** Native list surface: 16px radius, hairline border, no shadow. */
export default function ListCard({ children, className }: { children: React.ReactNode; className?: string }) {
  return (
    <div className={cn('overflow-hidden rounded-2xl border border-flat-border bg-flat-surface', className)}>
      {children}
    </div>
  )
}

export function ListRow({
  children,
  className,
  as: Tag = 'div',
  ...props
}: React.HTMLAttributes<HTMLElement> & { as?: React.ElementType }) {
  return (
    <Tag
      className={cn(
        'flex min-h-11 items-center gap-3 border-b border-flat-border px-4 py-3 last:border-b-0',
        className,
      )}
      {...props}
    >
      {children}
    </Tag>
  )
}
