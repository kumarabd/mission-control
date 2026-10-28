import { useState } from 'react'
import {
  ArrowDown,
  CheckCircle2,
  Circle,
  Ellipsis,
  RefreshCw,
  SquarePen,
  Star,
  Trash2,
} from 'lucide-react'
import { formatMinutes, type Item } from '../../lib/life'
import { Button, Menu, type MenuItem } from '../ui'
import ListCard from '../mission/ListCard'

export type TaskDeckProps = {
  items: Item[]
  busyItemId?: string | null
  movedToBottom: Set<string>
  onOpenTask: (item: Item) => void
  onCompleteTask: (item: Item, done: boolean) => void
  onTogglePriority: (item: Item) => void
  onMoveToBottom: (item: Item) => void
  onDeleteTask: (item: Item) => void
  onAddTask: () => void
}

/**
 * Native Task Deck: open tasks without a time, priority first, then the rest.
 * Timed work belongs to the schedule.
 */
export default function TaskDeck({
  items,
  busyItemId,
  movedToBottom,
  onOpenTask,
  onCompleteTask,
  onTogglePriority,
  onMoveToBottom,
  onDeleteTask,
  onAddTask,
}: TaskDeckProps) {
  const [showEmpty] = useState(true)
  const ordered = [
    ...items.filter((item) => item.is_priority && !movedToBottom.has(item.id)),
    ...items.filter((item) => !item.is_priority && !movedToBottom.has(item.id)),
    ...items.filter((item) => movedToBottom.has(item.id)),
  ]

  return (
    <section aria-labelledby="tasks-heading">
      <div className="mb-2 flex items-baseline justify-between gap-3">
        <h2 id="tasks-heading" className="text-native-body font-medium text-flat-foreground">
          Tasks
        </h2>
        {ordered.length > 0 && (
          <span className="text-2xs tabular-nums text-flat-muted-fg">{ordered.length} to do</span>
        )}
      </div>

      <ListCard>
        {ordered.map((item) => (
          <TaskRow
            key={item.id}
            item={item}
            busy={busyItemId === item.id}
            moved={movedToBottom.has(item.id)}
            onOpen={onOpenTask}
            onComplete={onCompleteTask}
            onTogglePriority={onTogglePriority}
            onMoveToBottom={onMoveToBottom}
            onDelete={onDeleteTask}
          />
        ))}

        {ordered.length === 0 && showEmpty && (
          <div className="px-4 py-7 text-center">
            <CheckCircle2 className="mx-auto size-6 text-flat-muted-fg" aria-hidden />
            <p className="mt-2 text-native-callout font-medium text-flat-foreground">
              Nothing on the deck.
            </p>
            <p className="mx-auto mt-1 max-w-sm text-sm text-flat-muted-fg">
              Add a task, or tell Chat what you want to get done.
            </p>
            <Button
              variant="secondary"
              size="sm"
              className="mt-3"
              iconLeft={<SquarePen className="size-4" aria-hidden />}
              onClick={onAddTask}
            >
              Add a task
            </Button>
          </div>
        )}
      </ListCard>

      <p className="mt-2 px-1 text-2xs text-flat-muted-fg">Things to do without a set time.</p>
    </section>
  )
}

function TaskRow({
  item,
  busy,
  moved,
  onOpen,
  onComplete,
  onTogglePriority,
  onMoveToBottom,
  onDelete,
}: {
  item: Item
  busy: boolean
  moved: boolean
  onOpen: (item: Item) => void
  onComplete: (item: Item, done: boolean) => void
  onTogglePriority: (item: Item) => void
  onMoveToBottom: (item: Item) => void
  onDelete: (item: Item) => void
}) {
  const menuItems: MenuItem[] = [
    { id: 'open', label: 'Open details', icon: <SquarePen />, onSelect: () => onOpen(item) },
    { id: 'done', label: 'Mark done', icon: <CheckCircle2 />, onSelect: () => onComplete(item, true) },
    {
      id: 'priority',
      label: item.is_priority ? 'Remove priority' : 'Make priority',
      icon: <Star />,
      onSelect: () => onTogglePriority(item),
    },
    ...(moved
      ? []
      : [
          {
            id: 'bottom',
            label: 'Move to bottom',
            icon: <ArrowDown />,
            onSelect: () => onMoveToBottom(item),
          } satisfies MenuItem,
        ]),
    { type: 'separator' as const, id: 'sep' },
    {
      id: 'delete',
      label: 'Delete task',
      icon: <Trash2 />,
      tone: 'danger' as const,
      onSelect: () => onDelete(item),
    },
  ]

  return (
    <div className="flex min-h-12 items-center gap-2 border-b border-flat-border py-1.5 pl-3 pr-1.5 last:border-b-0">
      <button
        type="button"
        aria-label={`Mark ${item.title} done`}
        onClick={() => onComplete(item, true)}
        disabled={busy}
        className="press grid size-9 shrink-0 place-items-center rounded-full text-flat-border-strong transition-colors hover:text-flat-primary focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-flat-primary focus-visible:ring-offset-2 focus-visible:ring-offset-flat-surface disabled:opacity-40"
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
          {item.recurrence ? 'Repeats' : item.minutes ? formatMinutes(item.minutes) : 'No estimate'}
          {item.is_priority ? ' · Priority' : ''}
        </span>
      </button>
      <Menu
        trigger={
          <button
            type="button"
            aria-label={`Options for ${item.title}`}
            className="inline-flex size-9 shrink-0 items-center justify-center rounded-sm text-flat-muted-fg transition-colors hover:bg-flat-muted hover:text-flat-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-flat-primary"
          >
            <Ellipsis className="size-4" aria-hidden />
          </button>
        }
        items={menuItems}
      />
    </div>
  )
}
