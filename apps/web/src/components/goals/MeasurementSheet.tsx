import { useState } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { Check, Gauge, Trash2 } from 'lucide-react'
import {
  dateTimeLocalValue,
  isLifeError,
  lifeKeys,
  toDateTimeLocal,
  useDeleteMeasurement,
  useRecordMeasurement,
  useUpdateMeasurement,
  type Measurement,
  type TrackerMetric,
} from '../../lib/life'
import { Button, Dialog, Field, Input, Textarea, useConfirm } from '../ui'

function errorMessageFor(error: unknown): string {
  if (isLifeError(error)) {
    if (error.kind === 'conflict') return 'That changed elsewhere. It has been refreshed.'
    if (error.kind === 'retry') return 'Your workspace is busy. Try again in a moment.'
  }
  return error instanceof Error ? error.message : 'Could not save this observation.'
}

/** Records or edits one observation for a tracker's check-in metric. */
export default function MeasurementSheet({
  goalId,
  metric,
  measurement,
  onOpenChange,
}: {
  goalId: string
  metric: TrackerMetric
  measurement?: Measurement | null
  onOpenChange: (open: boolean) => void
}) {
  const qc = useQueryClient()
  const confirm = useConfirm()
  const record = useRecordMeasurement()
  const update = useUpdateMeasurement()
  const remove = useDeleteMeasurement()

  const [value, setValue] = useState(measurement ? String(measurement.value) : '')
  const [measuredAt, setMeasuredAt] = useState(
    measurement ? toDateTimeLocal(measurement.measured_at) : dateTimeLocalValue(new Date()),
  )
  const [notes, setNotes] = useState(measurement?.notes ?? '')
  const [error, setError] = useState<string | null>(null)

  const busy = record.isPending || update.isPending || remove.isPending
  const parsed = Number(value)
  const valid =
    value.trim() !== '' &&
    Number.isFinite(parsed) &&
    (metric.minimum == null || parsed >= metric.minimum) &&
    (metric.maximum == null || parsed <= metric.maximum)

  const report = (cause: unknown) => {
    setError(errorMessageFor(cause))
    if (isLifeError(cause) && cause.kind === 'conflict') {
      void qc.invalidateQueries({ queryKey: lifeKeys.trackers() })
      void qc.invalidateQueries({ queryKey: lifeKeys.goal(goalId) })
    }
  }

  const save = async () => {
    if (!valid) return
    setError(null)
    const measuredIso = measuredAt ? new Date(measuredAt).toISOString() : new Date().toISOString()
    try {
      if (measurement) {
        await update.mutateAsync({
          goalId,
          measurement,
          value: parsed,
          measuredAt: measuredIso,
          notes: notes.trim() || null,
        })
      } else {
        await record.mutateAsync({
          goalId,
          metricId: metric.id,
          value: parsed,
          measuredAt: measuredIso,
          notes: notes.trim() || null,
        })
      }
      onOpenChange(false)
    } catch (cause) {
      report(cause)
    }
  }

  const deleteObservation = async () => {
    if (!measurement) return
    const yes = await confirm({
      title: 'Delete this observation?',
      body: 'The recorded value will be removed from the trend.',
      confirmLabel: 'Delete',
      tone: 'danger',
    })
    if (!yes) return
    setError(null)
    try {
      await remove.mutateAsync({ goalId, measurement })
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
      title={measurement ? 'Edit observation' : `Record ${metric.label.toLowerCase()}`}
      description={metric.target != null ? `Target ${metric.target} ${metric.unit}` : undefined}
      placement="responsive"
      dismissible={!busy}
      footer={
        <div className="flex w-full items-center gap-2">
          {measurement && (
            <Button
              variant="ghost"
              size="sm"
              className="text-flat-danger"
              onClick={() => void deleteObservation()}
              disabled={busy}
              iconLeft={<Trash2 className="size-4" aria-hidden />}
            >
              Delete
            </Button>
          )}
          <span className="flex-1" />
          <Button variant="ghost" size="md" onClick={() => onOpenChange(false)} disabled={busy}>
            Cancel
          </Button>
          <Button
            variant="primary"
            size="md"
            onClick={() => void save()}
            loading={busy}
            disabled={busy || !valid}
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
        <Field
          label={`${metric.label}${metric.unit ? ` (${metric.unit})` : ''}`}
          hint={
            metric.minimum != null || metric.maximum != null
              ? `Accepts ${metric.minimum ?? '−∞'} to ${metric.maximum ?? '∞'} ${metric.unit}`
              : undefined
          }
          error={
            value.trim() !== '' && !valid
              ? `Enter a number${metric.minimum != null || metric.maximum != null ? ' within the accepted range' : ''}.`
              : undefined
          }
        >
          <Input
            type="number"
            inputMode="decimal"
            step="any"
            value={value}
            onChange={(event) => setValue(event.target.value)}
            inputSize="native"
            placeholder={metric.target != null ? String(metric.target) : '0'}
            iconLeft={<Gauge className="size-4" aria-hidden />}
            autoFocus
            data-autofocus
          />
        </Field>

        <Field label="Measured at">
          <Input
            type="datetime-local"
            value={measuredAt}
            onChange={(event) => setMeasuredAt(event.target.value)}
          />
        </Field>

        <Field label="Notes (optional)">
          <Textarea
            value={notes}
            onChange={(event) => setNotes(event.target.value)}
            placeholder="Anything worth remembering about this reading"
            rows={2}
            maxLength={1000}
          />
        </Field>

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
