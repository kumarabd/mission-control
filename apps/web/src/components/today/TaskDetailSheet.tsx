import { useState } from 'react'
import { Check, Minus, Plus, Target, Trash2 } from 'lucide-react'
import {
  formatDateTime,
  formatMinutes,
  isLifeError,
  toDateTimeLocal,
  useCompleteTask,
  useDeleteEvent,
  useDeleteTask,
  useUpdateEvent,
  useUpdateTask,
  type Item,
} from '../../lib/life'
import { Button, Dialog, Field, Input, Switch, useConfirm } from '../ui'

function errorMessageFor(error: unknown): string | null {
  if (!error) return null
  if (isLifeError(error)) {
    if (error.kind === 'conflict') return 'That changed elsewhere. It has been refreshed.'
    if (error.kind === 'retry') return 'Your workspace is busy. Try again in a moment.'
  }
  return error instanceof Error ? error.message : 'Could not save this.'
}

/** Native item detail: edit, complete, prioritise, or delete one task or event. */
export default function TaskDetailSheet({
  item,
  onOpenChange,
  onOpenGoal,
}: {
  item: Item
  onOpenChange: (open: boolean) => void
  onOpenGoal: (goalId: string) => void
}) {
  const isEvent = item.kind === 'event'
  const updateTask = useUpdateTask()
  const updateEvent = useUpdateEvent()
  const complete = useCompleteTask()
  const removeTask = useDeleteTask()
  const removeEvent = useDeleteEvent()
  const confirm = useConfirm()

  const [title, setTitle] = useState(item.title)
  const [minutes, setMinutes] = useState(item.minutes || 25)
  const [priority, setPriority] = useState(Boolean(item.is_priority))
  const [at, setAt] = useState(toDateTimeLocal(item.at))
  const [error, setError] = useState<string | null>(null)

  const update = isEvent ? updateEvent : updateTask
  const remove = isEvent ? removeEvent : removeTask
  const busy = update.isPending || complete.isPending || remove.isPending
  const done = Boolean(item.done_at)

  const report = (cause: unknown) => setError(errorMessageFor(cause))

  const save = async () => {
    const clean = title.trim()
    if (!clean) return
    setError(null)
    try {
      await update.mutateAsync({
        item,
        title: clean,
        minutes,
        is_priority: priority,
        at: at ? new Date(at).toISOString() : null,
      })
      onOpenChange(false)
    } catch (cause) {
      report(cause)
    }
  }

  const toggleDone = async () => {
    setError(null)
    try {
      await complete.mutateAsync({ item, done: !done })
      onOpenChange(false)
    } catch (cause) {
      report(cause)
    }
  }

  const deleteItem = async () => {
    const yes = await confirm({
      title: isEvent ? 'Delete this event?' : 'Delete this task?',
      body: `“${item.title}” will be removed.`,
      confirmLabel: 'Delete',
      tone: 'danger',
    })
    if (!yes) return
    setError(null)
    try {
      await remove.mutateAsync(item)
      onOpenChange(false)
    } catch (cause) {
      report(cause)
    }
  }

  return (
    <Dialog
      open
      onOpenChange={(next) => {
        if (!busy) onOpenChange(next)
      }}
      title={done ? 'Task done' : isEvent ? 'Event' : 'Task'}
      description={
        isEvent || item.at
          ? formatDateTime(item.at)
          : 'No set time'
      }
      placement="responsive"
      dismissible={!busy}
      footer={
        <div className="flex w-full items-center gap-2">
          <Button
            variant="ghost"
            size="sm"
            className="text-flat-danger"
            onClick={() => void deleteItem()}
            disabled={busy}
            iconLeft={<Trash2 className="size-4" aria-hidden />}
          >
            Delete
          </Button>
          <span className="flex-1" />
          {!isEvent && (
            <Button variant="secondary" size="md" onClick={() => void toggleDone()} disabled={busy}>
              {done ? 'Mark not done' : 'Mark done'}
            </Button>
          )}
          <Button
            variant="primary"
            size="md"
            onClick={() => void save()}
            loading={update.isPending}
            disabled={busy || !title.trim()}
            iconLeft={<Check className="size-4" aria-hidden />}
          >
            Save
          </Button>
        </div>
      }
    >
      <form
        onSubmit={(event) => {
          event.preventDefault()
          void save()
        }}
        className="flex flex-col gap-4"
      >
        <Field label={isEvent ? 'Event' : 'Task'}>
          <Input
            value={title}
            onChange={(event) => setTitle(event.target.value)}
            inputSize="native"
            maxLength={200}
            autoFocus
            data-autofocus
          />
        </Field>

        <div className="flex flex-col gap-1.5">
          <span className="text-sm font-medium text-flat-foreground">How long?</span>
          <div className="flex items-center gap-2">
            <Button
              variant="secondary"
              size="sm"
              aria-label="Fewer minutes"
              onClick={() => setMinutes((value) => Math.max(5, value - 5))}
              disabled={minutes <= 5}
            >
              <Minus className="size-4" aria-hidden />
            </Button>
            <span className="min-w-20 text-center font-mono text-native-body tabular-nums text-flat-foreground">
              {minutes} min
            </span>
            <Button
              variant="secondary"
              size="sm"
              aria-label="More minutes"
              onClick={() => setMinutes((value) => Math.min(240, value + 5))}
              disabled={minutes >= 240}
            >
              <Plus className="size-4" aria-hidden />
            </Button>
            <span className="ml-1 text-xs text-flat-muted-fg">{formatMinutes(minutes)}</span>
          </div>
        </div>

        <Field
          label={isEvent ? 'Starts' : 'Time'}
          hint={isEvent ? undefined : 'Leave empty to keep it on the task deck.'}
        >
          <Input
            type="datetime-local"
            value={at}
            onChange={(event) => setAt(event.target.value)}
            required={isEvent}
          />
        </Field>

        {!isEvent && (
          <Switch
            checked={priority}
            onCheckedChange={setPriority}
            label="One of today’s priorities"
            className="min-h-11"
          />
        )}

        {item.goal_id && (
          <button
            type="button"
            onClick={() => {
              onOpenChange(false)
              onOpenGoal(item.goal_id!)
            }}
            className="flex min-h-11 items-center gap-2 rounded-sm border border-flat-border px-3 text-left text-native-callout text-flat-foreground hover:bg-flat-muted focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-flat-primary"
          >
            <Target className="size-4 text-flat-primary" aria-hidden />
            <span className="flex-1">Linked to a goal</span>
            <span className="text-2xs text-flat-muted-fg">Open</span>
          </button>
        )}

        {done && (
          <p className="rounded-md bg-flat-muted px-3 py-2 text-sm text-flat-muted-fg">
            Completed. You can still edit it or mark it not done.
          </p>
        )}

        {error && (
          <p
            role="alert"
            className="rounded-md border border-flat-warning/30 bg-flat-warning-muted px-3 py-2 text-sm text-flat-foreground"
          >
            {error}
          </p>
        )}
      </form>
    </Dialog>
  )
}
