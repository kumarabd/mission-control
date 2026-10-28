import { useQueries } from '@tanstack/react-query'
import { isLifeError, providerRequest } from './client'
import { life } from './operations'
import { lifeKeys } from './queryKeys'
import { parseDay, seriesRange } from './time'
import { observationsFor } from './tracker'
import { kitData, type KitData, type Point } from './viewkit'
import type { GoalView, MetricSource, SeriesData, TaskHistory, ViewState } from './wire'

/** Where a metric's live data stands. A block whose data has not arrived says so rather than drawing a guess. */
export type KitLoad = { status: 'pending' | 'error' | 'ready'; message?: string; gone?: boolean }

const SERIES_DAYS = 400
const ROUTINE_DAYS = 120

function retryFor(failureCount: number, error: unknown) {
  return isLifeError(error) && error.kind === 'retry' && failureCount < 2
}

/**
 * The data a view's calculations read, one entry per metric: the numbers the person logs come with the view; a
 * provider's series and a routine's logs are read live. A metric that cannot be read says why, and only the blocks
 * that use it show that.
 */
export function useKitData(view: GoalView | null | undefined, state: ViewState | undefined) {
  const bound = (view?.metrics ?? []).filter((metric) => metric.source || metric.task_id || metric.routine_id)
  const queries = useQueries({
    queries: bound.map((metric) => {
      if (metric.source) {
        const source: MetricSource = metric.source
        const range = seriesRange(SERIES_DAYS)
        const granularity = source.granularity || 'day'
        return {
          queryKey: lifeKeys.series(source.provider, source.series, range.from, range.to, granularity),
          queryFn: ({ signal }: { signal: AbortSignal }) =>
            providerRequest<SeriesData>(source.provider, 'series_get', { series: source.series, from: range.from, to: range.to, granularity }, { signal }),
          retry: retryFor,
          staleTime: 60_000,
        }
      }
      const taskId = (metric.task_id ?? metric.routine_id) as string
      return {
        queryKey: lifeKeys.taskHistory(taskId, ROUTINE_DAYS),
        queryFn: () => life.tasksHistory(taskId, ROUTINE_DAYS) as Promise<TaskHistory>,
        retry: retryFor,
        staleTime: 60_000,
      }
    }),
  })

  const series: Record<string, Point[]> = {}
  const loads: Record<string, KitLoad> = {}
  for (const metric of view?.metrics ?? []) {
    if (!metric.source && !metric.task_id && !metric.routine_id) {
      series[metric.id] = observationsFor(state, metric.id).map((m) => ({ date: new Date(m.measured_at), value: m.value }))
      loads[metric.id] = { status: 'ready' }
    }
  }
  bound.forEach((metric, i) => {
    const q = queries[i]
    if (q.isError) {
      const gone = isLifeError(q.error) && q.error.kind === 'not_found'
      loads[metric.id] = { status: 'error', gone, message: gone ? 'This data source no longer exists.' : q.error instanceof Error ? q.error.message : 'Could not read this data.' }
    } else if (q.data) {
      loads[metric.id] = { status: 'ready' }
      series[metric.id] = metric.source
        ? (q.data as SeriesData).points.map((p) => ({ date: parseDay(p.t), value: p.value }))
        : (q.data as TaskHistory).days.filter((d) => d.count > 0).map((d) => ({ date: parseDay(d.day), value: d.count }))
    } else {
      loads[metric.id] = { status: 'pending' }
    }
  })
  const data: KitData = kitData(series)
  return { data, loads, retry: () => queries.forEach((q) => void q.refetch()) }
}
