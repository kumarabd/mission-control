import { cn } from '../../lib/cn'

type SkeletonProps = {
  variant?: 'text' | 'block' | 'circle'
  lines?: number
  width?: string | number
  height?: string | number
  className?: string
}

const shimmer =
  'animate-pulse rounded-xs bg-flat-muted motion-reduce:animate-none'

export default function Skeleton({ variant = 'block', lines = 1, width, height, className }: SkeletonProps) {
  if (variant === 'text' && lines > 1) {
    return (
      <div className={cn('flex flex-col gap-1.5', className)}>
        {Array.from({ length: lines }).map((_, i) => (
          <div
            key={i}
            className={cn(shimmer, 'h-3.5')}
            style={{ width: i === lines - 1 ? '60%' : '100%' }}
          />
        ))}
      </div>
    )
  }
  return (
    <div
      className={cn(
        shimmer,
        variant === 'text' && 'h-3.5',
        variant === 'circle' && 'rounded-full',
        className,
      )}
      style={{ width, height: height ?? (variant === 'text' ? undefined : height) }}
    />
  )
}

export function SkeletonRows({ count = 6, className }: { count?: number; className?: string }) {
  return (
    <div className={cn('flex flex-col divide-y divide-flat-border', className)}>
      {Array.from({ length: count }).map((_, i) => (
        <div key={i} className="flex items-center gap-4 py-3">
          <Skeleton className="h-4 w-24" />
          <Skeleton className="h-4 flex-1" />
          <Skeleton className="h-4 w-16" />
          <Skeleton className="h-4 w-20" />
        </div>
      ))}
    </div>
  )
}

export function SkeletonCard({ className }: { className?: string }) {
  return (
    <div className={cn('rounded-md border border-flat-border bg-flat-surface p-4', className)}>
      <Skeleton className="h-4 w-1/3" />
      <Skeleton variant="text" lines={3} className="mt-3" />
    </div>
  )
}

export function SkeletonStatRow({ count = 4 }: { count?: number }) {
  return (
    <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
      {Array.from({ length: count }).map((_, i) => (
        <div key={i} className="rounded-md border border-flat-border bg-flat-surface p-3.5">
          <Skeleton className="h-3 w-16" />
          <Skeleton className="mt-2 h-7 w-20" />
        </div>
      ))}
    </div>
  )
}

export function PageSkeleton() {
  return (
    <div className="flex flex-col gap-6">
      <div>
        <Skeleton className="h-7 w-48" />
        <Skeleton className="mt-2 h-4 w-80" />
      </div>
      <SkeletonStatRow />
      <SkeletonCard />
    </div>
  )
}
