import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { CalendarDays, Check, Circle, RefreshCw } from 'lucide-react'
import { cn } from '../../lib/cn'
import { formatTime, type DayEntry, type Item } from '../../lib/life'
import { useNow } from '../../lib/useNow'
import { Button } from '../ui'
import ListCard from '../mission/ListCard'

type Row = { type: 'entry'; entry: DayEntry } | { type: 'now' }

function startMs(entry: DayEntry): number {
  const value = new Date(entry.at).getTime()
  return Number.isNaN(value) ? Number.POSITIVE_INFINITY : value
}

/**
 * Native Schedule window: the day's task and event occurrences with a Now rule placed between the last past entry
 * and the first future one. The window is roughly four rows tall and keeps the Now rule in view without a calendar.
 */
export default function ScheduleWindow({
  entries,
  onOpen,
}: {
  entries: DayEntry[]
  onOpen: (item: Item) => void
}) {
  const now = useNow()
  const nowMs = now.getTime()
  const scroller = useRef<HTMLDivElement>(null)
  const nowRow = useRef<HTMLDivElement>(null)
  const [away, setAway] = useState(false)

  const rows = useMemo<Row[]>(() => {
    const sorted = [...entries].sort((a, b) => startMs(a) - startMs(b))
    const result: Row[] = []
    let inserted = false
    for (const entry of sorted) {
      if (!inserted && startMs(entry) > nowMs) {
        result.push({ type: 'now' })
        inserted = true
      }
      result.push({ type: 'entry', entry })
    }
    if (!inserted) result.push({ type: 'now' })
    return result
    // Now only decides placement; recomputing once a minute is enough.
  }, [entries, nowMs])

  const center = useCallback((smooth = false) => {
    const container = scroller.current
    const marker = nowRow.current
    if (!container || !marker) return
    const target = Math.max(0, marker.offsetTop - container.clientHeight / 2 + marker.offsetHeight / 2)
    container.scrollTo({ top: target, behavior: smooth ? 'smooth' : 'auto' })
    setAway(false)
  }, [])

  useEffect(() => {
    const frame = requestAnimationFrame(() => center())
    return () => cancelAnimationFrame(frame)
  }, [entries.length, center])

  const onScroll = () => {
    const container = scroller.current
    const marker = nowRow.current
    if (!container || !marker) return
    const target = Math.max(0, marker.offsetTop - container.clientHeight / 2 + marker.offsetHeight / 2)
    setAway(Math.abs(container.scrollTop - target) > 12)
  }

  return (
    <section aria-labelledby="schedule-heading">
      <div className="mb-2 flex items-center justify-between gap-3">
        <h2 id="schedule-heading" className="text-native-body font-medium text-flat-foreground">
          Schedule
        </h2>
        {away && entries.length > 0 && (
          <Button variant="ghost" size="sm" onClick={() => center(true)}>
            Back to now
          </Button>
        )}
      </div>

      {entries.length === 0 ? (
        <ListCard>
          <div className="flex items-center gap-3 px-4 py-5">
            <CalendarDays className="size-4 shrink-0 text-flat-muted-fg" aria-hidden />
            <p className="text-native-callout text-flat-muted-fg">No timed items today.</p>
          </div>
        </ListCard>
      ) : (
        <ListCard>
          <div
            ref={scroller}
            onScroll={onScroll}
            tabIndex={0}
            aria-label="Today’s schedule"
            className="relative max-h-[268px] overflow-y-auto focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-flat-primary"
          >
            {rows.map((row) =>
              row.type === 'now' ? (
                <div
                  key="now"
                  ref={nowRow}
                  role="separator"
                  aria-label={`Now, ${formatTime(now.toISOString())}`}
                  className="flex items-center gap-3 bg-flat-surface px-4 py-1.5"
                >
                  <span className="w-14 shrink-0 font-mono text-2xs uppercase tracking-wide text-flat-primary">
                    Now
                  </span>
                  <span className="h-px flex-1 bg-flat-primary/40" />
                  <span className="font-mono text-2xs tabular-nums text-flat-primary">
                    {formatTime(now.toISOString())}
                  </span>
                </div>
              ) : (
                <ScheduleRow key={`${row.entry.item.id}:${row.entry.at}`} entry={row.entry} onOpen={onOpen} />
              ),
            )}
          </div>
        </ListCard>
      )}
    </section>
  )
}

function ScheduleRow({ entry, onOpen }: { entry: DayEntry; onOpen: (item: Item) => void }) {
  const item = entry.item
  const done = entry.state === 'done' || Boolean(item.done_at)
  const isEvent = item.kind === 'event'
  const meta = entry.overdue
    ? 'Overdue'
    : isEvent
      ? 'Event'
      : done
        ? 'Done'
        : item.recurrence
          ? 'Repeating task'
          : item.minutes
            ? `${item.minutes} min`
            : 'Task'

  return (
    <button
      type="button"
      onClick={() => onOpen(item)}
      className="press flex min-h-12 w-full items-center gap-3 border-b border-flat-border px-4 py-2.5 text-left transition-colors last:border-b-0 hover:bg-flat-muted/60 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-flat-primary"
    >
      <span className="w-14 shrink-0 font-mono text-2xs tabular-nums text-flat-muted-fg">
        {formatTime(entry.at)}
      </span>
      {isEvent ? (
        <span className="flex size-6 shrink-0 items-center justify-center rounded-full bg-flat-scheduled-muted text-flat-scheduled">
          <CalendarDays className="size-3.5" aria-hidden />
        </span>
      ) : (
        <span
          className={cn(
            'flex size-6 shrink-0 items-center justify-center rounded-full border',
            done
              ? 'border-flat-primary bg-flat-primary text-flat-on-accent'
              : 'border-flat-border text-transparent',
          )}
        >
          {done ? <Check className="size-3.5" aria-hidden /> : <Circle className="size-2" aria-hidden />}
        </span>
      )}
      <span className="min-w-0 flex-1">
        <span
          className={cn(
            'block truncate text-native-callout',
            done ? 'text-flat-muted-fg line-through' : 'text-flat-foreground',
          )}
        >
          {item.title}
        </span>
        <span
          className={cn(
            'flex items-center gap-1 text-2xs',
            entry.overdue ? 'text-flat-attention' : 'text-flat-muted-fg',
          )}
        >
          {entry.overdue && <RefreshCw className="size-3" aria-hidden />}
          {meta}
          {item.is_priority && !done ? ' · Priority' : ''}
        </span>
      </span>
    </button>
  )
}
