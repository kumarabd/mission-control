export default function AppSkeleton() {
  return (
    <div className="flex h-screen w-full">
      <div className="hidden w-60 shrink-0 border-r border-flat-border bg-flat-surface lg:block">
        <div className="h-14 border-b border-flat-border" />
        <div className="space-y-2 p-3">
          {Array.from({ length: 8 }).map((_, i) => (
            <div key={i} className="h-7 animate-pulse rounded-sm bg-flat-muted motion-reduce:animate-none" />
          ))}
        </div>
      </div>
      <div className="flex min-w-0 flex-1 flex-col">
        <div className="h-14 border-b border-flat-border bg-flat-surface" />
        <div className="flex-1 space-y-4 p-6">
          <div className="h-7 w-48 animate-pulse rounded-sm bg-flat-muted motion-reduce:animate-none" />
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            {Array.from({ length: 4 }).map((_, i) => (
              <div key={i} className="h-20 animate-pulse rounded-md bg-flat-muted motion-reduce:animate-none" />
            ))}
          </div>
        </div>
      </div>
    </div>
  )
}
