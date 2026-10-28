import { CalendarDays, CloudOff, RefreshCw } from 'lucide-react'
import {
  formatDateTime,
  isLifeError,
  useEvents,
  type Item,
} from '../../lib/life'
import { EmptyState } from '../ui'
import { useNow } from '../../lib/useNow'
import ListCard from '../mission/ListCard'
import InlineError from '../mission/InlineError'
import { ListSkeleton } from './GoalsList'

/** Events, soonest first: things that happen at a time whether or not anyone acts. */
export default function EventsList({
  onOpen,
  onNew,
}: {
  onOpen: (item: Item) => void
  onNew: () => void
}) {
  const events = useEvents()
  const now = useNow()

  if (events.isPending) return <ListSkeleton rows={5} />
  if (isLifeError(events.error) && events.error.kind === 'not_provisioned') {
    return (
      <EmptyState
        icon={<CloudOff />}
        title="Events need your workspace"
        body="They are kept with your assistant, which isn’t reachable right now."
      />
    )
  }
  if (events.isError) {
    return (
      <InlineError
        title="Couldn’t load events"
        description={events.error instanceof Error ? events.error.message : undefined}
        onRetry={() => void events.refetch()}
      />
    )
  }

  const cutoff = now.getTime() - 60 * 60_000
  const items = (events.data.items ?? [])
    .filter((item) => item.recurrence || !item.at || new Date(item.at).getTime() >= cutoff)
    .sort((a, b) => (a.at ?? '9999').localeCompare(b.at ?? '9999'))

  if (items.length === 0) {
    return (
      <EmptyState
        icon={<CalendarDays />}
        title="Nothing coming up"
        body="Add an event, or tell your assistant about something that happens at a set time."
        action={{ label: 'Add an event', onClick: onNew }}
      />
    )
  }

  return (
    <ListCard>
      {items.map((item) => (
        <button
          key={item.id}
          type="button"
          onClick={() => onOpen(item)}
          className="press flex min-h-14 w-full items-center gap-3 border-b border-flat-border px-4 py-2 text-left transition-colors last:border-b-0 hover:bg-flat-muted/60 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-flat-primary"
        >
          <CalendarDays className="size-4 shrink-0 text-flat-scheduled" aria-hidden />
          <span className="min-w-0 flex-1">
            <span className="block truncate text-native-callout text-flat-foreground">
              {item.title}
            </span>
            <span className="mt-0.5 flex items-center gap-1 text-2xs text-flat-muted-fg">
              {item.at ? formatDateTime(item.at) : 'No set time'}
              {item.recurrence && <RefreshCw className="size-3" aria-hidden />}
            </span>
          </span>
        </button>
      ))}
    </ListCard>
  )
}
