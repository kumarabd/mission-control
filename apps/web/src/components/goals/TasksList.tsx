import { CheckCircle2, Circle, CloudOff, RefreshCw, Star } from 'lucide-react'
import {
  formatDateTime,
  formatMinutes,
  isLifeError,
  useCompleteTask,
  useOpenTasks,
  type Item,
} from '../../lib/life'
import { EmptyState } from '../ui'
import ListCard from '../mission/ListCard'
import InlineError from '../mission/InlineError'
import { ListSkeleton } from './GoalsList'

/** Open tasks, soonest first, untimed last: the clean-slate engine has one kind of task, repeating or not. */
export default function TasksList({
  onOpen,
  onNew,
}: {
  onOpen: (item: Item) => void
  onNew: () => void
}) {
  const tasks = useOpenTasks()
  const complete = useCompleteTask()

  if (tasks.isPending) return <ListSkeleton rows={5} />
  if (isLifeError(tasks.error) && tasks.error.kind === 'not_provisioned') {
    return (
      <EmptyState
        icon={<CloudOff />}
        title="Tasks need your workspace"
        body="They are kept with your assistant, which isn’t reachable right now."
      />
    )
  }
  if (tasks.isError) {
    return (
      <InlineError
        title="Couldn’t load tasks"
        description={tasks.error instanceof Error ? tasks.error.message : undefined}
        onRetry={() => void tasks.refetch()}
      />
    )
  }

  const items = [...(tasks.data.items ?? [])].sort((a, b) => {
    if (Boolean(a.is_priority) !== Boolean(b.is_priority)) return a.is_priority ? -1 : 1
    return (a.at ?? '9999').localeCompare(b.at ?? '9999')
  })

  if (items.length === 0) {
    return (
      <EmptyState
        icon={<CheckCircle2 />}
        title="Nothing waiting"
        body="Add a task, or tell your assistant what you want to get done."
        action={{ label: 'Add a task', onClick: onNew }}
      />
    )
  }

  return (
    <ListCard>
      {items.map((item) => {
        const busy = complete.isPending && complete.variables?.item.id === item.id
        return (
          <div
            key={item.id}
            className="flex min-h-14 items-center gap-3 border-b border-flat-border px-4 py-2 last:border-b-0"
          >
            <button
              type="button"
              onClick={() => complete.mutate({ item, done: true })}
              disabled={busy}
              aria-label={`Mark ${item.title} done`}
              className="shrink-0 text-flat-primary focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-flat-primary disabled:opacity-40"
            >
              <Circle className="size-5" aria-hidden />
            </button>
            <button
              type="button"
              onClick={() => onOpen(item)}
              className="min-w-0 flex-1 rounded-sm py-1 text-left focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-flat-primary"
            >
              <span className="flex items-center gap-1.5">
                {item.is_priority && (
                  <Star className="size-3.5 shrink-0 fill-flat-attention text-flat-attention" aria-hidden />
                )}
                <span className="min-w-0 truncate text-native-callout text-flat-foreground">
                  {item.title}
                </span>
              </span>
              <span className="mt-0.5 flex items-center gap-1 text-2xs text-flat-muted-fg">
                {item.recurrence && <RefreshCw className="size-3" aria-hidden />}
                {item.at ? formatDateTime(item.at) : 'No set time'}
                {item.recurrence ? ' · Repeats' : item.minutes ? ` · ${formatMinutes(item.minutes)}` : ''}
              </span>
            </button>
          </div>
        )
      })}
    </ListCard>
  )
}
