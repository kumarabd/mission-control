import {
  ThreadListItemPrimitive,
  ThreadListPrimitive,
  useAuiState,
} from '@assistant-ui/react'
import { ChevronRight, GitBranch, GitFork, LoaderCircle, SquarePen } from 'lucide-react'
import type { FC } from 'react'
import { cn } from '../lib/cn'

type ConversationListProps = {
  isLoading?: boolean
  onNavigate?: () => void
  className?: string
  /** The sheet already has its own title; keep only the new-session action. */
  showHeading?: boolean
  /** Branch a conversation: the gateway copies its context into a child, shown under it in this list. */
  onFork?: (sessionId: string) => void
  /** Expand or collapse a conversation's forks; collapsed folders hide their children. */
  onToggleExpand?: (sessionId: string) => void
}

function relativeTime(value: unknown): string {
  if (typeof value !== 'string') return ''
  const timestamp = Date.parse(value)
  if (Number.isNaN(timestamp)) return ''
  const seconds = Math.max(0, Math.round((Date.now() - timestamp) / 1000))
  if (seconds < 60) return 'now'
  const minutes = Math.floor(seconds / 60)
  if (minutes < 60) return `${minutes}m`
  const hours = Math.floor(minutes / 60)
  if (hours < 24) return `${hours}h`
  const days = Math.floor(hours / 24)
  if (days < 7) return `${days}d`
  return new Intl.DateTimeFormat(undefined, { month: 'short', day: 'numeric' }).format(timestamp)
}

const ConversationItem: FC<{
  onNavigate?: () => void
  onFork?: (sessionId: string) => void
  onToggleExpand?: (sessionId: string) => void
}> = ({ onNavigate, onFork, onToggleExpand }) => {
  const id = useAuiState((state) => state.threadListItem.id)
  const custom = useAuiState((state) => state.threadListItem.custom)
  const isActive = useAuiState((state) => state.threads.mainThreadId === state.threadListItem.id)
  const isFork = custom?.isFork === true
  const isRunning = custom?.isRunning === true
  const depth = typeof custom?.depth === 'number' ? custom.depth : 0
  const hasChildren = typeof custom?.childCount === 'number' && custom.childCount > 0
  const expanded = custom?.expanded === true

  return (
    <ThreadListItemPrimitive.Root className="group/session relative" style={{ paddingLeft: depth * 14 }}>
      <div className="flex items-center gap-1">
        {hasChildren && onToggleExpand ? (
          <button
            type="button"
            onClick={() => onToggleExpand(id)}
            aria-expanded={expanded}
            aria-label={expanded ? 'Collapse forks' : 'Expand forks'}
            className="flex size-8 shrink-0 items-center justify-center rounded-lg text-flat-muted-fg transition-colors hover:bg-flat-muted hover:text-flat-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-flat-primary"
          >
            <ChevronRight
              className={cn('size-3.5 transition-transform', expanded && 'rotate-90')}
              aria-hidden
            />
          </button>
        ) : (
          <span className="size-8 shrink-0" aria-hidden />
        )}
        <ThreadListItemPrimitive.Trigger
          onClick={onNavigate}
          className={cn(
            'flex min-w-0 flex-1 items-center gap-2 rounded-xl border px-3 text-left transition-colors',
            'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-flat-primary',
            isFork ? 'min-h-9 py-1.5 text-xs' : 'min-h-11 py-2 text-native-callout',
            isActive
              ? 'border-flat-border bg-flat-tint text-flat-foreground'
              : 'border-transparent text-flat-muted-fg hover:bg-flat-muted',
          )}
        >
          {isFork && <GitBranch className="size-3 shrink-0 text-flat-muted-fg" aria-hidden />}
          <span className="min-w-0 flex-1 truncate font-medium">
            <ThreadListItemPrimitive.Title fallback="New session" />
          </span>
          {isRunning ? (
            <LoaderCircle
              className="size-3 shrink-0 animate-spin text-flat-primary motion-reduce:animate-none"
              aria-label="Running"
            />
          ) : (
            <span className="shrink-0 font-mono text-[10px] text-flat-subtle-fg">
              {relativeTime(custom?.updatedAt)}
            </span>
          )}
        </ThreadListItemPrimitive.Trigger>
        {onFork && (
          <button
            type="button"
            onClick={(event) => {
              event.stopPropagation()
              onFork(id)
            }}
            aria-label="Fork this conversation"
            title="Fork this conversation"
            className={cn(
              'flex size-8 shrink-0 items-center justify-center rounded-lg text-flat-muted-fg transition-opacity hover:bg-flat-muted hover:text-flat-foreground focus-visible:opacity-100 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-flat-primary',
              isActive
                ? 'opacity-100'
                : 'opacity-0 group-hover/session:opacity-100 group-focus-within/session:opacity-100 max-md:opacity-100',
            )}
          >
            <GitFork className="size-3.5" aria-hidden />
          </button>
        )}
      </div>
    </ThreadListItemPrimitive.Root>
  )
}

export function ConversationList({
  isLoading,
  onNavigate,
  className,
  showHeading = true,
  onFork,
  onToggleExpand,
}: ConversationListProps) {
  return (
    <ThreadListPrimitive.Root className={cn('flex min-h-0 flex-col', className)}>
      <div className="flex items-center justify-between px-4 pb-2 pt-3">
        {showHeading ? (
          <h2 className="text-2xs font-medium uppercase tracking-[0.12em] text-flat-subtle-fg">
            Conversations
          </h2>
        ) : (
          <span />
        )}
        <ThreadListPrimitive.New
          onClick={onNavigate}
          className="flex size-9 items-center justify-center rounded-sm text-flat-muted-fg transition-colors hover:bg-flat-muted hover:text-flat-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-flat-primary"
          aria-label="New session"
          title="New session"
        >
          <SquarePen className="size-4" aria-hidden />
        </ThreadListPrimitive.New>
      </div>
      <div className="min-h-0 flex-1 overflow-y-auto px-2 pb-3">
        {isLoading && (
          <div className="space-y-2 px-1 py-2" aria-label="Loading conversations">
            <div className="h-12 animate-pulse rounded-xl bg-flat-muted motion-reduce:animate-none" />
            <div className="h-12 animate-pulse rounded-xl bg-flat-muted motion-reduce:animate-none" />
          </div>
        )}
        <ThreadListPrimitive.Items
          components={{
            ThreadListItem: () => (
              <ConversationItem
                onNavigate={onNavigate}
                onFork={onFork}
                onToggleExpand={onToggleExpand}
              />
            ),
          }}
        />
      </div>
    </ThreadListPrimitive.Root>
  )
}
