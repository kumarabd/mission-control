import { useNavigate } from 'react-router-dom'
import { CheckCheck, ChevronRight, Inbox, RefreshCw } from 'lucide-react'
import { Button, EmptyState, IconButton, Skeleton, toast } from '../components/ui'
import Screen from '../components/mission/Screen'
import InlineError from '../components/mission/InlineError'
import ListCard from '../components/mission/ListCard'
import { cn } from '../lib/cn'
import {
  useMarkAllNotificationsRead,
  useMarkNotificationRead,
  useNotifications,
  type GatewayNotification,
} from '../lib/notifications'

function targetPath(item: GatewayNotification): string | null {
  if (!item.link) return null
  switch (item.link.entity) {
    case 'intention':
    case 'commitment':
    case 'decision':
    case 'goal':
      return '/life' 
    case 'task':
    case 'event':
    case 'plan_item':
      return `/today?item=${item.link.id}`
    case 'routine':
    case 'reminder':
      return '/life' 
    default:
      return null
  }
}

function whenLabel(iso: string): string {
  const date = new Date(iso)
  if (Number.isNaN(date.getTime())) return ''
  const now = new Date()
  const sameDay =
    date.getFullYear() === now.getFullYear() &&
    date.getMonth() === now.getMonth() &&
    date.getDate() === now.getDate()
  return new Intl.DateTimeFormat(undefined, {
    ...(sameDay ? {} : { month: 'short', day: 'numeric' }),
    hour: 'numeric',
    minute: '2-digit',
  }).format(date)
}

export default function Notifications() {
  const navigate = useNavigate()
  const inbox = useNotifications()
  const markRead = useMarkNotificationRead()
  const markAll = useMarkAllNotificationsRead()

  const items = (() => {
    const seen = new Set<string>()
    const result: GatewayNotification[] = []
    for (const page of inbox.data?.pages ?? []) {
      for (const item of page.items) {
        if (seen.has(item.id)) continue
        seen.add(item.id)
        result.push(item)
      }
    }
    return result
  })()
  const unread = inbox.data?.pages[0]?.unread ?? 0

  const open = (item: GatewayNotification) => {
    if (!item.read_at) {
      markRead.mutate(item.id, {
        onError: () => toast.error('Could not mark this notification read.'),
      })
    }
    const path = targetPath(item)
    if (path) navigate(path)
  }

  return (
    <Screen
      title="Notifications"
      description="What your assistant has sent: check-ins, schedule results, and updates about your plans."
      actions={
        <>
          {unread > 0 && (
            <Button
              variant="secondary"
              size="sm"
              loading={markAll.isPending}
              onClick={() => markAll.mutate()}
              iconLeft={<CheckCheck className="size-4" aria-hidden />}
            >
              Mark all read
            </Button>
          )}
          <IconButton
            label="Refresh notifications"
            size="lg"
            onClick={() => void inbox.refetch()}
          >
            <RefreshCw
              className={cn(
                inbox.isFetching && !inbox.isFetchingNextPage && 'animate-spin motion-reduce:animate-none',
              )}
              aria-hidden
            />
          </IconButton>
        </>
      }
    >
      {inbox.isPending ? (
        <div className="rounded-2xl border border-flat-border bg-flat-surface p-4" aria-busy="true">
          <div className="flex flex-col gap-5">
            {Array.from({ length: 4 }).map((_, index) => (
              <div key={index} className="flex items-start gap-3">
                <Skeleton variant="circle" className="mt-1 size-2" />
                <div className="flex-1">
                  <Skeleton className="h-4 w-2/3" />
                  <Skeleton className="mt-2 h-3 w-full" />
                </div>
              </div>
            ))}
          </div>
        </div>
      ) : inbox.isError && !items.length ? (
        <InlineError
          title="Couldn’t load notifications"
          description={
            inbox.error instanceof Error
              ? inbox.error.message
              : 'Your notification inbox is unavailable.'
          }
          onRetry={() => void inbox.refetch()}
        />
      ) : items.length === 0 ? (
        <div className="rounded-2xl border border-flat-border bg-flat-surface">
          <EmptyState
            icon={<Inbox />}
            title="Nothing yet"
            body="Reminders, nudges and check-ins your assistant speaks about appear here."
          />
        </div>
      ) : (
        <div className="flex flex-col gap-3">
          <ListCard>
            {items.map((item) => {
              const unreadItem = !item.read_at
              const path = targetPath(item)
              return (
                <button
                  key={item.id}
                  type="button"
                  onClick={() => open(item)}
                  className="press flex min-h-14 w-full items-start gap-2.5 border-b border-flat-border px-4 py-3 text-left last:border-b-0 hover:bg-flat-muted/50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-flat-primary"
                >
                  <span
                    className={cn(
                      'mt-1.5 size-2 shrink-0 rounded-full',
                      unreadItem ? 'bg-flat-primary' : 'bg-transparent',
                    )}
                    aria-hidden
                  />
                  <span className="min-w-0 flex-1">
                    <span
                      className={cn(
                        'block text-native-callout text-flat-foreground',
                        unreadItem ? 'font-medium' : 'font-normal text-flat-muted-fg',
                      )}
                    >
                      {item.title}
                    </span>
                    {item.body && (
                      <span className="mt-0.5 line-clamp-2 block text-sm text-flat-muted-fg">
                        {item.body}
                      </span>
                    )}
                    <span className="mt-1 block font-mono text-2xs text-flat-muted-fg">
                      {item.priority === 'high' ? 'High priority · ' : ''}
                      {whenLabel(item.created_at)}
                    </span>
                  </span>
                  {path && (
                    <ChevronRight
                      className="mt-1 size-4 shrink-0 text-flat-border-strong"
                      aria-hidden
                    />
                  )}
                </button>
              )
            })}
          </ListCard>

          {inbox.hasNextPage && (
            <Button
              variant="secondary"
              size="touch"
              className="self-start"
              loading={inbox.isFetchingNextPage}
              onClick={() => void inbox.fetchNextPage()}
            >
              More
            </Button>
          )}

          <p className="px-1 text-2xs text-flat-muted-fg">
            Sent by your assistant. Nudges it decided against were never sent, so they are not
            listed.
          </p>
        </div>
      )}

      {inbox.isError && items.length > 0 && (
        <div className="mt-3">
          <InlineError
            title="Some notifications didn’t load"
            description={inbox.error instanceof Error ? inbox.error.message : undefined}
            onRetry={() => void inbox.refetch()}
          />
        </div>
      )}
    </Screen>
  )
}
