import { useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { useQueryClient } from '@tanstack/react-query'
import {
  CalendarDays,
  ChartLine,
  CheckCircle2,
  ChevronLeft,
  Circle,
  CloudOff,
  Flag,
  MessageSquare,
  RefreshCw,
  SquarePen,
} from 'lucide-react'
import MeasurementSheet from '../components/goals/MeasurementSheet'
import KitBlock, { type KitActions } from '../components/goals/KitBlock'
import { Button, EmptyState, IconButton, Skeleton, Tabs, toast } from '../components/ui'
import Screen from '../components/mission/Screen'
import InlineError from '../components/mission/InlineError'
import ListCard from '../components/mission/ListCard'
import ProgressBar from '../components/mission/ProgressBar'
import { cn } from '../lib/cn'
import { useAutoComposeView } from '../lib/life/useAutoComposeView'
import { useChatDraft } from '../lib/chatDraft'
import {
  formatDateTime,
  formatDay,
  goalProgress,
  isLifeError,
  lifeKeys,
  TRACKER_CATALOG,
  viewForCatalog,
  useCompleteTask,
  useGoal,
  useGoalItems,
  useGoalView,
  useKitData,
  useRecordMeasurement,
  type Goal,
  type Item,
  type Measurement,
  type ViewMetric,
} from '../lib/life'

type MeasurementTarget = { metric: ViewMetric; measurement: Measurement | null }

export default function GoalDetail() {
  const { goalId = '' } = useParams()
  const navigate = useNavigate()
  const qc = useQueryClient()
  const requestDraft = useChatDraft((state) => state.request)

  const goal = useGoal(goalId)
  const goalItems = useGoalItems(goalId)
  const primary = useGoalView(goalId, TRACKER_CATALOG)
  const view = viewForCatalog(primary.data, TRACKER_CATALOG)
  const tracker = primary.data
  const kit = useKitData(view, tracker)
  const composePrompt = goal.data
    ? `Compose a view for my goal ${goal.data.id}, “${goal.data.title}”. Read the view kit (tracker_catalog_get) and the goal first, design what suits this goal, then save it with views_create (or views_update if it has one). `
    : ''
  const compose = useAutoComposeView({
    goalId,
    prompt: composePrompt,
    ready: primary.isSuccess && Boolean(goal.data),
    hasView: view !== null,
    refetch: primary.refetch,
  })
  const recordMeasurement = useRecordMeasurement()

  const completeTask = useCompleteTask()
  const kitActions: KitActions = {
    onRetry: kit.retry,
    onCheckIn: (metric, observation) => setMeasurement({ metric, measurement: observation }),
    // The clean-slate engine has no goal steps or routine logs: a view's repeating task is ticked off as a task.
    onStep: () => {},
    onLogDay: () => {},
    onRecord: async (metric, value) => {
      try {
        await recordMeasurement.mutateAsync({ goalId, metricId: metric.id, value })
        return null
      } catch (error) {
        return error instanceof Error ? error.message : 'Could not save this.'
      }
    },
  }

  const [measurement, setMeasurement] = useState<MeasurementTarget | null>(null)
  const [pageId, setPageId] = useState('')
  const page = view?.pages.find((p) => p.id === pageId) ?? view?.pages[0]

  const talk = (draft: string) => {
    requestDraft(draft)
    navigate('/chat')
  }

  const refresh = () => {
    void qc.invalidateQueries({ queryKey: lifeKeys.goals() })
    void qc.invalidateQueries({ queryKey: lifeKeys.goal(goalId) })
    void qc.invalidateQueries({ queryKey: lifeKeys.trackers() })
    void qc.invalidateQueries({ queryKey: lifeKeys.goalItems(goalId) })
  }

  const back = (
    <Link
      to="/goals"
      className="inline-flex items-center gap-1 text-flat-muted-fg hover:text-flat-foreground"
    >
      <ChevronLeft className="size-3.5" aria-hidden />
      Goals
    </Link>
  )

  if (goal.isPending) {
    return (
      <Screen eyebrow={back} title="Goal">
        <div className="flex flex-col gap-4" aria-busy="true">
          <Skeleton className="h-6 w-2/3" />
          <Skeleton className="h-4 w-1/2" />
          <Skeleton className="h-40 rounded-2xl" />
          <Skeleton className="h-40 rounded-2xl" />
        </div>
      </Screen>
    )
  }

  if (isLifeError(goal.error) && goal.error.kind === 'not_provisioned') {
    return (
      <Screen eyebrow={back} title="Goal">
        <EmptyState
          icon={<CloudOff />}
          title="Goals need your workspace"
          body="They are kept with your assistant, which isn’t reachable right now."
        />
      </Screen>
    )
  }

  if (goal.isError) {
    const gone = isLifeError(goal.error) && goal.error.kind === 'not_found'
    return (
      <Screen eyebrow={back} title={gone ? 'This goal is gone' : 'Goal'}>
        {gone ? (
          <EmptyState
            icon={<Flag />}
            title="This goal is gone"
            body="It was archived or removed."
            action={{ label: 'Back to goals', to: '/goals' }}
          />
        ) : (
          <InlineError
            title="Couldn’t load this goal"
            description={goal.error instanceof Error ? goal.error.message : undefined}
            onRetry={() => void goal.refetch()}
          />
        )}
      </Screen>
    )
  }

  const data = goal.data
  const progress = goalProgress(data)
  const trackerProblem =
    primary.isError &&
    !(isLifeError(primary.error) && ['not_found', 'unknown'].includes(primary.error.code)) &&
    !view
      ? primary.error instanceof Error
        ? primary.error
        : new Error('Could not load this tracker.')
      : null

  const buildTracker = () => compose.again()

  return (
    <Screen
      eyebrow={back}
      title={data.title}
      description={data.notes || undefined}
      actions={
        <>
          <IconButton
            label="Talk about this goal"
            size="lg"
            onClick={() => talk(`About my goal “${data.title}”: `)}
          >
            <MessageSquare aria-hidden />
          </IconButton>
          <IconButton label="Refresh goal" size="lg" onClick={refresh}>
            <RefreshCw
              className={cn(
                (goal.isFetching || primary.isFetching) && 'animate-spin motion-reduce:animate-none',
              )}
              aria-hidden
            />
          </IconButton>
        </>
      }
    >
      <div className="flex flex-col gap-4">
        <div className="flex flex-wrap items-baseline gap-x-4 gap-y-1 text-sm text-flat-muted-fg">
          <span>
            {progress.done} of {progress.total} tasks done
          </span>
          {data.ends_on && (
            <span className="font-mono text-2xs">
              Ends {formatDay(data.ends_on, { weekday: 'short', month: 'short', day: 'numeric' })}
            </span>
          )}
        </div>

        {trackerProblem && (
          <InlineError
            title="The tracker didn’t load"
            description={
              trackerProblem instanceof Error ? trackerProblem.message : undefined
            }
            onRetry={() => void primary.refetch()}
          />
        )}

        {primary.isPending ? (
          <div className="grid gap-4 md:grid-cols-2" aria-busy="true">
            <Skeleton className="h-44 rounded-2xl" />
            <Skeleton className="h-44 rounded-2xl" />
          </div>
        ) : view && tracker && page ? (
          <>
            {view.pages.length > 1 && (
              <Tabs
                value={page.id}
                onValueChange={setPageId}
                items={view.pages.map((p) => ({ value: p.id, label: p.title }))}
              />
            )}
            <div className="flex flex-col gap-8">
              {page.sections.map((section) => (
                <section key={section.id} aria-labelledby={`sec-${section.id}`} className="flex flex-col gap-3">
                  <div className="flex flex-col gap-1">
                    <h2 id={`sec-${section.id}`} className="text-native-title3 font-semibold text-flat-foreground">
                      {section.title}
                    </h2>
                    {section.intro && <p className="max-w-prose text-sm text-flat-muted-fg">{section.intro}</p>}
                  </div>
                  <div className="grid items-start gap-4 md:grid-cols-2">
                    {section.blocks.map((block, index) => (
                      <KitBlock
                        key={block.id}
                        block={block}
                        view={view}
                        state={tracker}
                        goal={data}
                        data={kit.data}
                        loads={kit.loads}
                        index={index}
                        actions={kitActions}
                      />
                    ))}
                  </div>
                </section>
              ))}
            </div>
            <div className="flex flex-wrap gap-2">
              <Button
                variant="secondary"
                size="touch"
                onClick={() => talk(`Change the view of goal “${data.title}”. My changes: `)}
                iconLeft={<SquarePen className="size-4" aria-hidden />}
              >
                Change this view
              </Button>
              <Button
                variant="ghost"
                size="touch"
                onClick={() =>
                  talk(
                    `I keep putting off “${data.title}”. Help me make it smaller. `,
                  )
                }
              >
                I keep putting this off
              </Button>
            </div>
          </>
        ) : (
          <GoalReview
            goal={data}
            items={goalItems.data ?? []}
            busyItemId={completeTask.isPending ? completeTask.variables?.item.id : null}
            onToggleItem={(item) =>
              completeTask.mutate(
                { item, done: !item.done_at },
                {
                  onError: (error) =>
                    toast.error(
                      error instanceof Error ? error.message : 'Could not update this.',
                    ),
                },
              )
            }
            composing={compose.composing}
            onBuildTracker={buildTracker}
            onTalk={talk}
          />
        )}
      </div>

      {measurement && tracker && (
        <MeasurementSheet
          key={measurement.measurement?.id ?? measurement.metric.id}
          goalId={data.id}
          metric={measurement.metric}
          measurement={measurement.measurement}
          onOpenChange={(open) => {
            if (!open) setMeasurement(null)
          }}
        />
      )}

    </Screen>
  )
}

function GoalReview({
  goal,
  items,
  busyItemId,
  onToggleItem,
  composing,
  onBuildTracker,
  onTalk,
}: {
  goal: Goal
  items: Item[]
  busyItemId?: string | null
  onToggleItem: (item: Item) => void
  composing: boolean
  onBuildTracker: () => void
  onTalk: (draft: string) => void
}) {
  const progress = goalProgress(goal)

  return (
    <div className="flex flex-col gap-4">
      {progress.total > 0 && (
        <div className="rounded-2xl border border-flat-border bg-flat-surface px-4 py-3">
          <ProgressBar
            value={progress.done}
            max={progress.total}
            label="Tasks done"
            detail={`${progress.done}/${progress.total}`}
          />
        </div>
      )}

      <section aria-labelledby="goal-items">
        <h2 id="goal-items" className="mb-2 text-native-callout font-medium text-flat-foreground">
          Tasks and events
        </h2>
        <ListCard>
          {items.length === 0 ? (
            <button
              type="button"
              onClick={() =>
                onTalk(`Add the tasks and events that serve “${goal.title}”, and link them to it.`)
              }
              className="flex min-h-12 w-full items-center gap-3 px-4 py-3 text-left text-native-callout text-flat-foreground hover:bg-flat-muted focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-flat-primary"
            >
              <Flag className="size-4 shrink-0 text-flat-primary" aria-hidden />
              No tasks or events serve this goal yet. Set them up with your assistant
            </button>
          ) : (
            items.map((item) => {
              const done = Boolean(item.done_at)
              return (
                <div
                  key={item.id}
                  className="flex min-h-14 items-center gap-3 border-b border-flat-border px-4 py-2 last:border-b-0"
                >
                  {item.kind === 'task' ? (
                    <button
                      type="button"
                      onClick={() => onToggleItem(item)}
                      disabled={busyItemId === item.id}
                      aria-label={done ? `Reopen ${item.title}` : `Mark ${item.title} done`}
                      className="shrink-0 text-flat-primary focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-flat-primary disabled:opacity-40"
                    >
                      {done ? (
                        <CheckCircle2 className="size-5" aria-hidden />
                      ) : (
                        <Circle className="size-5" aria-hidden />
                      )}
                    </button>
                  ) : (
                    <CalendarDays className="size-4 shrink-0 text-flat-muted-fg" aria-hidden />
                  )}
                  <div className="min-w-0 flex-1">
                    <span
                      className={cn(
                        'block truncate text-native-callout',
                        done ? 'text-flat-muted-fg line-through' : 'text-flat-foreground',
                      )}
                    >
                      {item.title}
                    </span>
                    <span className="block text-2xs text-flat-muted-fg">
                      {item.kind === 'event' ? 'Event' : item.recurrence ? 'Repeating task' : 'Task'}
                      {item.at ? ` · ${formatDateTime(item.at)}` : ''}
                    </span>
                  </div>
                </div>
              )
            })
          )}
        </ListCard>
        <p className="mt-1.5 px-1 text-2xs text-flat-muted-fg">
          Tasks and events are set up and changed by your assistant, in Chat.
        </p>
      </section>

      <div className="flex flex-wrap gap-2">
        {composing ? (
          <p role="status" className="flex items-center gap-2 text-sm text-flat-muted-fg">
            <RefreshCw className="size-4 animate-spin motion-reduce:animate-none" aria-hidden />
            Building this view… the assistant is composing it for this goal.
          </p>
        ) : (
        <Button
            variant="primary"
            size="touch"
            onClick={onBuildTracker}
            iconLeft={<ChartLine className="size-4" aria-hidden />}
          >
            Build a view for this goal
          </Button>
        )}
        <Button
          variant="secondary"
          size="touch"
          onClick={() => onTalk(`About my goal “${goal.title}”: `)}
          iconLeft={<MessageSquare className="size-4" aria-hidden />}
        >
          Change this with your assistant
        </Button>
        <Button
          variant="ghost"
          size="touch"
          onClick={() =>
            onTalk(`I keep putting off “${goal.title}”. Help me make it smaller. `)
          }
        >
          I keep putting this off
        </Button>
      </div>
      <p className="text-2xs text-flat-muted-fg">
        Routines, steps and the goal itself are set up and changed by your assistant, in Chat.
      </p>
    </div>
  )
}
