import { useState } from 'react'
import { Minus, Plus, SquarePen } from 'lucide-react'
import { isLifeError, useCreateTask } from '../../lib/life'
import { Button, Dialog, Field, Input, Switch } from '../ui'

const MIN_MINUTES = 5
const MAX_MINUTES = 240
const STEP = 5
const DEFAULT_MINUTES = 25

/**
 * Native Add Task sheet: what, how long, and whether it is a priority today.
 * Mounted fresh each time it opens, so its draft never leaks between opens.
 */
export default function AddTaskSheet({
  onOpenChange,
}: {
  onOpenChange: (open: boolean) => void
}) {
  const create = useCreateTask()
  const [title, setTitle] = useState('')
  const [minutes, setMinutes] = useState(DEFAULT_MINUTES)
  const [priority, setPriority] = useState(false)

  const submit = async () => {
    const clean = title.trim()
    if (!clean) return
    try {
      await create.mutateAsync({
        title: clean,
        minutes,
        is_priority: priority,
      })
      onOpenChange(false)
    } catch {
      /* the sheet shows the error and keeps the input */
    }
  }

  const error = create.error
  const errorMessage = error
    ? isLifeError(error) && error.kind === 'retry'
      ? 'Your workspace is busy. Try again in a moment.'
      : error instanceof Error
        ? error.message
        : 'Could not add this task.'
    : null

  return (
    <Dialog
      open
      onOpenChange={(next) => {
        if (!create.isPending) onOpenChange(next)
      }}
      title="Add to today"
      placement="responsive"
      dismissible={!create.isPending}
      footer={
        <>
          <Button
            variant="ghost"
            size="md"
            onClick={() => onOpenChange(false)}
            disabled={create.isPending}
          >
            Cancel
          </Button>
          <Button
            type="submit"
            form="add-task-form"
            variant="primary"
            size="md"
            loading={create.isPending}
            disabled={!title.trim()}
            iconLeft={<SquarePen className="size-4" aria-hidden />}
          >
            Add
          </Button>
        </>
      }
    >
      <form
        id="add-task-form"
        onSubmit={(event) => {
          event.preventDefault()
          void submit()
        }}
        className="flex flex-col gap-4"
      >
        <Field label="What will you do?">
          <Input
            value={title}
            onChange={(event) => setTitle(event.target.value)}
            placeholder="Draft the launch note"
            inputSize="native"
            maxLength={200}
            autoFocus
            data-autofocus
            enterKeyHint="done"
          />
        </Field>

        <div className="flex flex-col gap-1.5">
          <span className="text-sm font-medium text-flat-foreground">How long?</span>
          <div className="flex items-center gap-2">
            <Button
              variant="secondary"
              size="sm"
              aria-label="Fewer minutes"
              onClick={() => setMinutes((value) => Math.max(MIN_MINUTES, value - STEP))}
              disabled={minutes <= MIN_MINUTES}
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
              onClick={() => setMinutes((value) => Math.min(MAX_MINUTES, value + STEP))}
              disabled={minutes >= MAX_MINUTES}
            >
              <Plus className="size-4" aria-hidden />
            </Button>
          </div>
          <p className="text-xs text-flat-muted-fg">Five minutes to four hours.</p>
        </div>

        <Switch
          checked={priority}
          onCheckedChange={setPriority}
          label="One of today’s priorities"
          className="min-h-11"
        />

        {errorMessage && (
          <p role="alert" className="rounded-md border border-flat-warning/30 bg-flat-warning-muted px-3 py-2 text-sm text-flat-foreground">
            {errorMessage}
          </p>
        )}
      </form>
    </Dialog>
  )
}
