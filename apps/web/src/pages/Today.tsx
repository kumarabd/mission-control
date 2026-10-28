import { useState } from 'react'
import { useNavigate, useSearchParams } from 'react-router-dom'
import { useQueryClient } from '@tanstack/react-query'
import { CloudOff, RefreshCw, SquarePen } from 'lucide-react'
import AddTaskSheet from '../components/today/AddTaskSheet'
import ScheduleWindow from '../components/today/ScheduleWindow'
import TaskDeck from '../components/today/TaskDeck'
import TaskDetailSheet from '../components/today/TaskDetailSheet'
import { EmptyState, IconButton, Skeleton, toast, useConfirm } from '../components/ui'
import Screen from '../components/mission/Screen'
import InlineError from '../components/mission/InlineError'
import { cn } from '../lib/cn'
import {
  formatDay,
  isLifeError,
  lifeKeys,
  localDay,
  useCompleteTask,
  useDay,
  useDeleteTask,
  useItem,
  useOpenTasks,
  useUpdateTask,
  type Item,
} from '../lib/life'

export default function Today() {
  const navigate = useNavigate()
  const [searchParams, setSearchParams] = useSearchParams()
  const qc = useQueryClient()
  const confirm = useConfirm()

  const day = useDay()
  const tasks = useOpenTasks()
  const complete = useCompleteTask()
  const update = useUpdateTask()
  const remove = useDeleteTask()

  const [manualAdd, setManualAdd] = useState(false)
  const [detailItem, setDetailItem] = useState<Item | null>(null)
  const [movedToBottom, setMovedToBottom] = useState<Set<string>>(() => new Set())

  const dayName = day.data?.day ?? localDay()
  const title = formatDay(dayName, { weekday: 'long', month: 'long', day: 'numeric' })

  // URLs are the source of truth for the add sheet and a deep-linked item;
  // local state covers taps and is cleared when the surface closes.
  const addParam = searchParams.get('add')
  const addTaskOpen = manualAdd || addParam === 'task'
  const itemParam = searchParams.get('item')
  const entries = day.data?.entries ?? []
  const openTasks = (tasks.data?.items ?? []).filter((item) => !item.at)
  const listed =
    entries.find((entry) => entry.item.id === itemParam)?.item ??
    openTasks.find((item) => item.id === itemParam) ??
    null
  // A receipt can deep-link a task or event that is not part of today; fetch that one by id.
  const linked = useItem(itemParam && !listed ? itemParam : '')
  const activeItem = detailItem ?? listed ?? linked.data ?? null

  const clearParam = (key: string) => {
    const nextParams = new URLSearchParams(searchParams)
    nextParams.delete(key)
    setSearchParams(nextParams, { replace: true })
  }

  const closeAdd = () => {
    setManualAdd(false)
    if (addParam) clearParam('add')
  }

  const closeDetail = () => {
    setDetailItem(null)
    if (itemParam) clearParam('item')
  }

  const doneCount = entries.filter((entry) => entry.state === 'done' || entry.item.done_at).length
  const summaryLine = entries.length
    ? `${doneCount} of ${entries.length} done today`
    : undefined

  const reportError = (error: unknown) => {
    const message =
      isLifeError(error) && error.kind === 'conflict'
        ? 'That changed elsewhere. It has been refreshed.'
        : error instanceof Error
          ? error.message
          : 'Something went wrong.'
    toast.error(message)
    if (isLifeError(error) && error.kind === 'conflict') {
      void qc.invalidateQueries({ queryKey: lifeKeys.all })
    }
  }

  const onComplete = (item: Item, done: boolean) => {
    complete.mutate({ item, done }, { onError: reportError })
  }

  const onTogglePriority = (item: Item) => {
    update.mutate(
      {
        item,
        title: item.title,
        minutes: item.minutes,
        at: item.at,
        is_priority: !item.is_priority,
        goal_id: item.goal_id,
      },
      { onError: reportError },
    )
  }

  const onDelete = (item: Item) => {
    void (async () => {
      const yes = await confirm({
        title: 'Delete this task?',
        body: `“${item.title}” will be removed.`,
        confirmLabel: 'Delete',
        tone: 'danger',
      })
      if (!yes) return
      remove.mutate(item, {
        onSuccess: () => {
          if (activeItem?.id === item.id) closeDetail()
        },
        onError: reportError,
      })
    })()
  }

  const isFetching = day.isFetching || tasks.isFetching
  const notProvisioned = isLifeError(day.error) && day.error.kind === 'not_provisioned'

  return (
    <Screen
      eyebrow={title}
      title="Today"
      description={summaryLine}
      actions={
        <>
          <IconButton label="Add a task" size="lg" onClick={() => setManualAdd(true)}>
            <SquarePen aria-hidden />
          </IconButton>
          <IconButton
            label="Refresh today"
            size="lg"
            className="max-sm:hidden"
            onClick={() => void qc.invalidateQueries({ queryKey: lifeKeys.all })}
          >
            <RefreshCw className={cn(isFetching && 'animate-spin motion-reduce:animate-none')} aria-hidden />
          </IconButton>
        </>
      }
    >
      {day.isPending ? (
        <TodaySkeleton />
      ) : notProvisioned ? (
        <div className="rounded-2xl border border-flat-border bg-flat-surface">
          <EmptyState
            icon={<CloudOff />}
            title="Today isn’t connected yet"
            body="This workspace isn’t provisioned for the Life Engine, so there is no day to show. Everything else in the console still works."
          />
        </div>
      ) : day.isError ? (
        <InlineError
          title="Today couldn’t load"
          description={day.error instanceof Error ? day.error.message : 'Could not load today.'}
          onRetry={() => void day.refetch()}
        />
      ) : (
        <div className="flex flex-col gap-7">
          {tasks.isError && (
            <InlineError
              title="Tasks didn’t load"
              description={tasks.error instanceof Error ? tasks.error.message : 'Could not load tasks.'}
              onRetry={() => void tasks.refetch()}
            />
          )}

          <ScheduleWindow entries={entries} onOpen={setDetailItem} />

          <TaskDeck
            items={openTasks}
            busyItemId={complete.isPending ? complete.variables?.item.id : null}
            movedToBottom={movedToBottom}
            onOpenTask={setDetailItem}
            onCompleteTask={onComplete}
            onTogglePriority={onTogglePriority}
            onMoveToBottom={(item) =>
              setMovedToBottom((current) => {
                const nextSet = new Set(current)
                nextSet.add(item.id)
                return nextSet
              })
            }
            onDeleteTask={onDelete}
            onAddTask={() => setManualAdd(true)}
          />
        </div>
      )}

      {addTaskOpen && <AddTaskSheet onOpenChange={(open) => {
        if (!open) closeAdd()
      }} />}

      {activeItem && (
        <TaskDetailSheet
          key={activeItem.id}
          item={activeItem}
          onOpenChange={(open) => {
            if (!open) closeDetail()
          }}
          onOpenGoal={(goalId) => {
            closeDetail()
            navigate(`/goals/${goalId}`)
          }}
        />
      )}
    </Screen>
  )
}

function TodaySkeleton() {
  return (
    <div className="flex flex-col gap-7" aria-busy="true" aria-label="Loading your day">
      <div>
        <Skeleton className="mb-2 h-4 w-24" />
        <Skeleton className="h-[268px] rounded-2xl" />
      </div>
      <div>
        <Skeleton className="mb-2 h-4 w-20" />
        <div className="rounded-2xl border border-flat-border bg-flat-surface p-4">
          <div className="flex flex-col gap-3">
            {Array.from({ length: 4 }).map((_, index) => (
              <div key={index} className="flex items-center gap-3">
                <Skeleton variant="circle" className="size-8" />
                <Skeleton className="h-4 flex-1" />
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  )
}
