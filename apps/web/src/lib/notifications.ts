import { useInfiniteQuery, useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  listNotifications,
  markAllNotificationsRead,
  markNotificationRead,
  type GatewayNotification,
} from './gateway'
import { notificationKeys } from './life/queryKeys'

export type { GatewayNotification }

/** The Gateway inbox, newest first. `fetchNextPage` carries `next_before` verbatim. */
export function useNotifications(enabled = true) {
  return useInfiniteQuery({
    queryKey: notificationKeys.list(),
    queryFn: ({ pageParam }) =>
      listNotifications({ limit: 50, before: pageParam as string | null }),
    initialPageParam: null as string | null,
    getNextPageParam: (last) => last.next_before ?? undefined,
    enabled,
    staleTime: 30_000,
    refetchInterval: 60_000,
  })
}

export function useNotificationUnread(enabled = true) {
  return useQuery({
    queryKey: notificationKeys.unread(),
    queryFn: async () => (await listNotifications({ limit: 1 })).unread,
    enabled,
    staleTime: 30_000,
    refetchInterval: 60_000,
  })
}

export function useMarkNotificationRead() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (id: string) => markNotificationRead(id),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: notificationKeys.all })
    },
  })
}

export function useMarkAllNotificationsRead() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: () => markAllNotificationsRead(),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: notificationKeys.all })
    },
  })
}
