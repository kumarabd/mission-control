import { useNavigate } from 'react-router-dom'
import { Check, CloudOff, SquarePen } from 'lucide-react'
import { EmptyState, IconButton, Skeleton, toast } from '../components/ui'
import Screen from '../components/mission/Screen'
import InlineError from '../components/mission/InlineError'
import ListCard from '../components/mission/ListCard'
import { formatDay, formatTime, isLifeError } from '../lib/life'
import { useCompleteTask, useDay, useOpenTasks, type DayEntry, type Task } from '../lib/life/personal'
import { useChatDraft } from '../lib/chatDraft'

function message(error: unknown): string {
  return error instanceof Error ? error.message : 'Something went wrong.'
}

export default function Today() {
  const navigate = useNavigate()
  const requestDraft = useChatDraft((state) => state.request)
  const day = useDay()
  const tasks = useOpenTasks()
  const complete = useCompleteTask()

  const entries = day.data?.entries ?? []
  const untimed = (tasks.data?.items ?? []).filter((task) => !task.at)
  const done = entries.filter((entry) => entry.state === 'done').length
  const title = day.data?.day
    ? formatDay(day.data.day, { weekday: 'long', month: 'long', day: 'numeric' })
    : 'Today'

  const startNew = () => {
    requestDraft('Remind me to ')
    navigate('/chat')
  }

  const finish = (task: Task, at?: string) =>
    complete.mutate(
      { task, at: task.recurrence ? at : undefined },
      {
        onSuccess: () => toast.success('Done.'),
        onError: (error) => toast.error(message(error)),
      },
    )

  if (day.isPending) {
    return (
      <Screen title="Today">
        <div className="flex flex-col gap-2">
          <Skeleton className="h-14 rounded-flat-md" />
          <Skeleton className="h-14 rounded-flat-md" />
          <Skeleton className="h-14 rounded-flat-md" />
        </div>
      </Screen>
    )
  }
  if (isLifeError(day.error) && day.error.kind === 'not_provisioned') {
    return (
      <Screen title="Today">
        <EmptyState icon={<CloudOff />} title="Today needs your workspace" body="It isn’t reachable right now." />
      </Screen>
    )
  }
  if (day.error) {
    return (
      <Screen title="Today">
        <InlineError title="Couldn’t load today" description={message(day.error)} onRetry={() => void day.refetch()} />
      </Screen>
    )
  }

  return (
    <Screen
      title={title}
      description={entries.length ? `${done} of ${entries.length} done` : undefined}
      actions={
        <IconButton label="Tell your assistant" size="lg" onClick={startNew}>
          <SquarePen aria-hidden />
        </IconButton>
      }
    >
      {entries.length === 0 && untimed.length === 0 ? (
        <EmptyState
          icon={<Check />}
          title="A clear day"
          body="Tell your assistant what needs doing and it will keep the day here."
          action={{ label: 'Tell your assistant', onClick: startNew }}
        />
      ) : (
        <div className="flex flex-col gap-5">
          {entries.length > 0 && (
            <ListCard>
              {entries.map((entry) => (
                <EntryRow
                  key={`${entry.task?.id ?? entry.event?.id}-${entry.at}`}
                  entry={entry}
                  pending={complete.isPending}
                  onComplete={() => entry.task && finish(entry.task, entry.at)}
                />
              ))}
            </ListCard>
          )}
          {untimed.length > 0 && (
            <section>
              <h2 className="mb-2 px-1 text-native-footnote font-medium uppercase tracking-wide text-flat-subtle-fg">Anytime</h2>
              <ListCard>
                {untimed.map((task) => (
                  <UntimedRow key={task.id} task={task} pending={complete.isPending} onComplete={() => finish(task)} />
                ))}
              </ListCard>
            </section>
          )}
        </div>
      )}
    </Screen>
  )
}

function EntryRow({ entry, onComplete, pending }: { entry: DayEntry; onComplete: () => void; pending: boolean }) {
  const task = entry.task
  const event = entry.event
  const title = task?.title ?? event?.title ?? ''
  const done = entry.state === 'done'
  const meta = [formatTime(entry.at), entry.overdue ? 'Overdue' : '', event ? 'Event' : task?.recurrence ? 'Routine' : '']
    .filter(Boolean)
    .join(' · ')
  return (
    <div className="flex min-h-14 items-center gap-3 border-b border-flat-border px-4 py-3 last:border-b-0">
      <span className="min-w-0 flex-1">
        <span className={done ? 'block text-native-callout text-flat-subtle-fg line-through' : 'block text-native-callout font-medium text-flat-foreground'}>
          {title}
        </span>
        <span className="mt-0.5 block text-native-footnote text-flat-subtle-fg">{meta}</span>
      </span>
      {task && !done && (
        <button
          type="button"
          disabled={pending}
          onClick={onComplete}
          className="press shrink-0 rounded-full border border-flat-border px-3 py-1 text-native-footnote font-medium text-flat-foreground transition-colors hover:bg-flat-muted/60 disabled:opacity-50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-flat-primary"
        >
          Done
        </button>
      )}
      {done && <Check className="size-4 shrink-0 text-flat-success" aria-label="Done" />}
    </div>
  )
}

function UntimedRow({ task, onComplete, pending }: { task: Task; onComplete: () => void; pending: boolean }) {
  return (
    <div className="flex min-h-14 items-center gap-3 border-b border-flat-border px-4 py-3 last:border-b-0">
      <span className="min-w-0 flex-1">
        <span className="block text-native-callout font-medium text-flat-foreground">{task.title}</span>
        {task.notes && <span className="mt-0.5 block text-native-footnote text-flat-subtle-fg">{task.notes}</span>}
      </span>
      <button
        type="button"
        disabled={pending}
        onClick={onComplete}
        className="press shrink-0 rounded-full border border-flat-border px-3 py-1 text-native-footnote font-medium text-flat-foreground transition-colors hover:bg-flat-muted/60 disabled:opacity-50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-flat-primary"
      >
        Done
      </button>
    </div>
  )
}
