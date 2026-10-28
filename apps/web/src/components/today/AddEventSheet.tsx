import { useState } from 'react'
import { CalendarPlus } from 'lucide-react'
import { isLifeError, useCreateEvent } from '../../lib/life'
import { Button, Dialog, Field, Input } from '../ui'

/** Native Add Event sheet: what happens, and when it starts. */
export default function AddEventSheet({ onOpenChange }: { onOpenChange: (open: boolean) => void }) {
  const create = useCreateEvent()
  const [title, setTitle] = useState('')
  const [at, setAt] = useState('')

  const submit = async () => {
    const clean = title.trim()
    if (!clean || !at) return
    try {
      await create.mutateAsync({ title: clean, at: new Date(at).toISOString() })
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
        : 'Could not add this event.'
    : null

  return (
    <Dialog
      open
      onOpenChange={(next) => {
        if (!create.isPending) onOpenChange(next)
      }}
      title="Add an event"
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
            form="add-event-form"
            variant="primary"
            size="md"
            loading={create.isPending}
            disabled={!title.trim() || !at}
            iconLeft={<CalendarPlus className="size-4" aria-hidden />}
          >
            Add
          </Button>
        </>
      }
    >
      <form
        id="add-event-form"
        onSubmit={(event) => {
          event.preventDefault()
          void submit()
        }}
        className="flex flex-col gap-4"
      >
        <Field label="What happens?">
          <Input
            value={title}
            onChange={(event) => setTitle(event.target.value)}
            placeholder="Dinner with Sam"
            inputSize="native"
            maxLength={200}
            autoFocus
            data-autofocus
            enterKeyHint="done"
          />
        </Field>

        <Field label="Starts">
          <Input
            type="datetime-local"
            value={at}
            onChange={(event) => setAt(event.target.value)}
            required
          />
        </Field>

        {errorMessage && (
          <p role="alert" className="rounded-md border border-flat-warning/30 bg-flat-warning-muted px-3 py-2 text-sm text-flat-foreground">
            {errorMessage}
          </p>
        )}
      </form>
    </Dialog>
  )
}
