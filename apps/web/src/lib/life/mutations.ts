import { useMutation, useQueryClient } from '@tanstack/react-query'
import { newIdempotencyKey } from './client'
import { life } from './operations'
import { lifeKeys } from './queryKeys'
import type { Item, Measurement } from './wire'

function useInvalidateLife() {
  const qc = useQueryClient()
  return () => {
    void qc.invalidateQueries({ queryKey: lifeKeys.day() })
    void qc.invalidateQueries({ queryKey: lifeKeys.tasks() })
    void qc.invalidateQueries({ queryKey: lifeKeys.events() })
    void qc.invalidateQueries({ queryKey: lifeKeys.goals() })
    void qc.invalidateQueries({ queryKey: lifeKeys.trackers() })
    void qc.invalidateQueries({ queryKey: ['life', 'goal-items'] })
  }
}

/** Marks a task done (or reopens it): the clean-slate engine's one way to tick anything off. */
export function useCompleteTask() {
  const qc = useQueryClient()
  const invalidate = useInvalidateLife()
  return useMutation({
    mutationFn: (input: { item: Item; done: boolean }) =>
      life.tasksComplete({
        idempotency_key: newIdempotencyKey(),
        id: input.item.id,
        expected_version: input.item.version,
        done: input.done,
      }),
    onSettled: () => {
      invalidate()
      void qc.invalidateQueries({ queryKey: ['life', 'goal-items'] })
    },
  })
}

export function useCreateTask() {
  const invalidate = useInvalidateLife()
  return useMutation({
    mutationFn: (input: { title: string; minutes?: number; is_priority?: boolean; at?: string | null; goal_id?: string }) =>
      life.tasksCreate({ idempotency_key: newIdempotencyKey(), ...input }),
    onSuccess: () => invalidate(),
  })
}

export function useUpdateTask() {
  const invalidate = useInvalidateLife()
  return useMutation({
    mutationFn: (input: {
      item: Item
      title: string
      minutes?: number | null
      at?: string | null
      is_priority?: boolean
      goal_id?: string | null
    }) =>
      life.tasksUpdate({
        idempotency_key: newIdempotencyKey(),
        id: input.item.id,
        expected_version: input.item.version,
        title: input.title,
        minutes: input.minutes ?? null,
        at: input.at ?? null,
        is_priority: input.is_priority ?? false,
        goal_id: input.goal_id ?? '',
      }),
    onSuccess: () => invalidate(),
  })
}

export function useDeleteTask() {
  const invalidate = useInvalidateLife()
  return useMutation({
    mutationFn: (item: Item) =>
      life.tasksDelete({ idempotency_key: newIdempotencyKey(), id: item.id, expected_version: item.version }),
    onSuccess: () => invalidate(),
  })
}

export function useCreateEvent() {
  const invalidate = useInvalidateLife()
  return useMutation({
    mutationFn: (input: { title: string; at: string; minutes?: number | null; goal_id?: string }) =>
      life.eventsCreate({ idempotency_key: newIdempotencyKey(), ...input }),
    onSuccess: () => invalidate(),
  })
}

export function useUpdateEvent() {
  const invalidate = useInvalidateLife()
  return useMutation({
    mutationFn: (input: {
      item: Item
      title: string
      at?: string | null
      minutes?: number | null
      goal_id?: string | null
    }) =>
      life.eventsUpdate({
        idempotency_key: newIdempotencyKey(),
        id: input.item.id,
        expected_version: input.item.version,
        title: input.title,
        at: input.at ?? input.item.at,
        minutes: input.minutes ?? null,
        goal_id: input.goal_id ?? '',
      }),
    onSuccess: () => invalidate(),
  })
}

export function useDeleteEvent() {
  const invalidate = useInvalidateLife()
  return useMutation({
    mutationFn: (item: Item) =>
      life.eventsDelete({ idempotency_key: newIdempotencyKey(), id: item.id, expected_version: item.version }),
    onSuccess: () => invalidate(),
  })
}











/* ---------- routines ---------- */





/* ---------- goals, measurements ---------- */

export function useRecordMeasurement() {
  const qc = useQueryClient()
  const invalidate = useInvalidateLife()
  return useMutation({
    mutationFn: (input: {
      goalId: string
      metricId: string
      value: number
      measuredAt?: string
      notes?: string | null
    }) =>
      life.measurementRecord({
        idempotency_key: newIdempotencyKey(),
        subject_kind: 'goal',
        subject_id: input.goalId,
        metric_id: input.metricId,
        value: input.value,
        measured_at: input.measuredAt,
        notes: input.notes ?? null,
      }),
    onSuccess: (_state, input) => {
      void invalidate()
      void qc.invalidateQueries({ queryKey: lifeKeys.goals() })
      void qc.invalidateQueries({ queryKey: lifeKeys.goal(input.goalId) })
      void qc.invalidateQueries({ queryKey: lifeKeys.trackers() })
    },
  })
}

export function useUpdateMeasurement() {
  const qc = useQueryClient()
  const invalidate = useInvalidateLife()
  return useMutation({
    mutationFn: (input: {
      goalId: string
      measurement: Measurement
      value: number
      measuredAt?: string
      notes?: string | null
    }) =>
      life.measurementUpdate({
        idempotency_key: newIdempotencyKey(),
        id: input.measurement.id,
        expected_version: input.measurement.version,
        value: input.value,
        measured_at: input.measuredAt,
        notes: input.notes ?? null,
      }),
    onSuccess: (_state, input) => {
      void invalidate()
      void qc.invalidateQueries({ queryKey: lifeKeys.goals() })
      void qc.invalidateQueries({ queryKey: lifeKeys.goal(input.goalId) })
      void qc.invalidateQueries({ queryKey: lifeKeys.trackers() })
    },
  })
}

export function useDeleteMeasurement() {
  const qc = useQueryClient()
  const invalidate = useInvalidateLife()
  return useMutation({
    mutationFn: (input: { goalId: string; measurement: Measurement }) =>
      life.measurementDelete({
        idempotency_key: newIdempotencyKey(),
        id: input.measurement.id,
        expected_version: input.measurement.version,
      }),
    onSuccess: (_state, input) => {
      void invalidate()
      void qc.invalidateQueries({ queryKey: lifeKeys.goals() })
      void qc.invalidateQueries({ queryKey: lifeKeys.goal(input.goalId) })
      void qc.invalidateQueries({ queryKey: lifeKeys.trackers() })
    },
  })
}
