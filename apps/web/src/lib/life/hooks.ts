import { useQuery } from '@tanstack/react-query'
import { life } from './operations'
import { lifeKeys } from './queryKeys'
import { isLifeError } from './client'

function retryLife(failureCount: number, error: unknown): boolean {
  return isLifeError(error) && error.kind === 'retry' && failureCount < 2
}

export function useLifeSettings() {
  return useQuery({
    queryKey: lifeKeys.settings(),
    queryFn: () => life.settingsGet(),
    retry: retryLife,
    staleTime: 5 * 60_000,
  })
}


/** Today, as the engine sees it: each occurrence of a task or event, plus open tasks still waiting from earlier days. */
export function useDay() {
  return useQuery({
    queryKey: lifeKeys.day(),
    queryFn: () => life.dayGet(),
    retry: retryLife,
    refetchInterval: 60_000,
  })
}

/** Open tasks, soonest first, untimed last. */
export function useOpenTasks() {
  return useQuery({
    queryKey: lifeKeys.tasks(),
    queryFn: () => life.tasksList({ status: 'open' }),
    retry: retryLife,
    refetchInterval: 60_000,
  })
}

/** The events the person has, soonest first; past ones are filtered where they are shown. */
export function useEvents() {
  return useQuery({
    queryKey: lifeKeys.events(),
    queryFn: () => life.eventsList(),
    retry: retryLife,
    refetchInterval: 60_000,
  })
}




export function useGoals() {
  return useQuery({
    queryKey: lifeKeys.goals(),
    queryFn: () => life.goalsList({ limit: 100 }),
    retry: retryLife,
    staleTime: 30_000,
  })
}

export function useGoal(goalId: string) {
  return useQuery({
    queryKey: lifeKeys.goal(goalId),
    queryFn: () => life.goalsGet(goalId),
    enabled: Boolean(goalId),
    retry: retryLife,
  })
}

/** One task or event by id, for a deep link; the kind is not known, so a task is tried first. */
export function useItem(id: string) {
  return useQuery({
    queryKey: lifeKeys.item(id),
    queryFn: async () => {
      try {
        return await life.tasksGet(id)
      } catch {
        return await life.eventsGet(id)
      }
    },
    enabled: Boolean(id),
    retry: retryLife,
  })
}

/** The tasks and events that serve a goal: what used to be its steps and routines. */
export function useGoalItems(goalId: string) {
  return useQuery({
    queryKey: lifeKeys.goalItems(goalId),
    queryFn: async () => {
      const [tasks, events] = await Promise.all([
        life.tasksList({ goal_id: goalId, status: 'all' }),
        life.eventsList({ goal_id: goalId }),
      ])
      return [...(tasks.items ?? []), ...(events.items ?? [])].sort((a, b) => {
        if (Boolean(a.done_at) !== Boolean(b.done_at)) return a.done_at ? 1 : -1
        return (a.at ?? '9999').localeCompare(b.at ?? '9999')
      })
    },
    enabled: Boolean(goalId),
    retry: retryLife,
  })
}



/** A goal's view for one client catalogue, with the observations recorded against its metrics. */
export function useGoalView(goalId: string, catalogId: string, enabled = true) {
  return useQuery({
    queryKey: lifeKeys.tracker(goalId, catalogId),
    queryFn: () => life.viewsState('goal', goalId, catalogId),
    enabled: Boolean(goalId) && enabled,
    retry: retryLife,
  })
}
