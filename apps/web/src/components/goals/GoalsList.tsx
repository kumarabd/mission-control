import { useNavigate } from 'react-router-dom'
import { CalendarDays, CloudOff, Flag, Target } from 'lucide-react'
import { formatDay, goalProgress, isLifeError, useGoals, type Goal } from '../../lib/life'
import { EmptyState, Skeleton } from '../ui'
import IconBadge from '../mission/IconBadge'
import InlineError from '../mission/InlineError'
import ListCard from '../mission/ListCard'
import ProgressBar from '../mission/ProgressBar'

export default function GoalsList({ onNew }: { onNew: () => void }) {
  const goals = useGoals()
  const navigate = useNavigate()

  if (goals.isPending) return <ListSkeleton />
  if (isLifeError(goals.error) && goals.error.kind === 'not_provisioned') {
    return (
      <EmptyState
        icon={<CloudOff />}
        title="Goals need your workspace"
        body="They are kept with your assistant, which isn’t reachable right now."
      />
    )
  }
  if (goals.isError) {
    return (
      <InlineError
        title="Couldn’t load goals"
        description={goals.error instanceof Error ? goals.error.message : undefined}
        onRetry={() => void goals.refetch()}
      />
    )
  }
  if (!goals.data.items.length) {
    return (
      <EmptyState
        icon={<Flag />}
        title="Start with one thing you care about"
        body="Tell your assistant what you want to achieve and it will turn it into small steps and routines."
        action={{ label: 'Tell your assistant', onClick: onNew }}
      />
    )
  }

  return (
    <ListCard>
      {goals.data.items.map((goal) => (
        <GoalRow key={goal.id} goal={goal} onOpen={() => navigate(`/goals/${goal.id}`)} />
      ))}
    </ListCard>
  )
}

function GoalRow({ goal, onOpen }: { goal: Goal; onOpen: () => void }) {
  const progress = goalProgress(goal)
  const next = goal.next ?? null
  const subline = next
    ? `Next: ${next.title}`
    : progress.total > 0
      ? `${progress.done} of ${progress.total} tasks done`
      : goal.notes?.trim() || 'No tasks yet'

  return (
    <button
      type="button"
      onClick={onOpen}
      className="press flex min-h-14 w-full items-start gap-3 border-b border-flat-border px-4 py-3 text-left transition-colors last:border-b-0 hover:bg-flat-muted/60 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-flat-primary"
    >
      <IconBadge icon={Target} tone="focus" size="sm" className="mt-0.5" />
      <span className="min-w-0 flex-1">
        <span className="block text-native-callout font-medium text-flat-foreground">
          {goal.title}
        </span>
        {progress.total > 0 ? (
          <ProgressBar
            className="mt-2 max-w-sm"
            value={progress.done}
            max={progress.total}
            label={subline}
            detail={`${Math.round((progress.done / Math.max(progress.total, 1)) * 100)}%`}
          />
        ) : (
          <span className="mt-0.5 block text-sm text-flat-muted-fg">{subline}</span>
        )}
        {goal.ends_on && (
          <span className="mt-1.5 inline-flex items-center gap-1 text-2xs text-flat-muted-fg">
            <CalendarDays className="size-3" aria-hidden />
            Ends {formatDay(goal.ends_on, { month: 'short', day: 'numeric' })}
          </span>
        )}
      </span>
    </button>
  )
}

export function ListSkeleton({ rows = 4 }: { rows?: number }) {
  return (
    <div className="rounded-2xl border border-flat-border bg-flat-surface p-4" aria-busy="true">
      <div className="flex flex-col gap-4">
        {Array.from({ length: rows }).map((_, index) => (
          <div key={index} className="flex items-start gap-3">
            <Skeleton variant="circle" className="size-8" />
            <div className="flex-1">
              <Skeleton className="h-4 w-1/3" />
              <Skeleton className="mt-2 h-3 w-2/3" />
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
