import { useNavigate } from 'react-router-dom'
import { Brain, CloudOff, MessageSquare, Network } from 'lucide-react'
import { ApiError } from '../lib/api'
import { useSemanticWorld } from '../lib/semanticMemory'
import { EmptyState, IconButton, Segmented, Skeleton } from '../components/ui'
import Screen from '../components/mission/Screen'
import InlineError from '../components/mission/InlineError'
import WorldGraph from '../components/mission/WorldGraph'
import { useChatDraft } from '../lib/chatDraft'
import { formatDateTime } from '../lib/life'

export default function MissionMemory() {
  const navigate = useNavigate()
  const requestDraft = useChatDraft((state) => state.request)
  const world = useSemanticWorld(true)

  const discussEntity = (entity?: string) => {
    requestDraft(entity ? `About ${entity} in my world: ` : 'About the people, places and things in my world: ')
    navigate('/chat')
  }

  const discuss = () => {
    requestDraft('About what you remember and understand about me: ')
    navigate('/chat')
  }

  return (
    <Screen
      title="Memory"
      description="The people, places and things your assistant knows about, and how they connect."
      actions={
        <IconButton label="Discuss memory" size="lg" onClick={discuss}>
          <MessageSquare aria-hidden />
        </IconButton>
      }
    >
      <Segmented
        className="mb-2"
        fullWidth
        value="world"
        onValueChange={() => undefined}
        options={[
          { value: 'world', label: 'World' },
          { value: 'about_you', label: 'About you · Soon', disabled: true },
        ]}
      />
      <p className="mb-4 text-2xs text-flat-muted-fg">
        About you is coming soon — your assistant’s understanding of you will appear here.
      </p>

      <WorldView world={world} onDiscuss={discussEntity} />
    </Screen>
  )
}

/** The World lens states: loading, an older service, signed out, failed, forming, or the diagram. */
function WorldView({
  world,
  onDiscuss,
}: {
  world: ReturnType<typeof useSemanticWorld>
  onDiscuss: (entity?: string) => void
}) {
  const error = world.error
  if (world.isPending) {
    return (
      <div className="rounded-2xl border border-flat-border bg-flat-surface p-4" aria-busy="true">
        <Skeleton className="h-3 w-24" />
        <Skeleton className="mt-3 h-64 w-full" />
      </div>
    )
  }
  if (error && !world.data) {
    if (error instanceof ApiError && error.status === 404) {
      return (
        <div className="rounded-2xl border border-flat-border bg-flat-surface">
          <EmptyState
            icon={<CloudOff />}
            title="Your memory needs a service update"
            body="This workspace’s memory service predates the world view. Chat and everything else still work."
          />
        </div>
      )
    }
    if (error instanceof ApiError && (error.status === 401 || error.status === 403)) {
      return (
        <div className="rounded-2xl border border-flat-border bg-flat-surface">
          <EmptyState icon={<Brain />} title="Please sign in again" body="Your assistant’s memory is tied to your account." />
        </div>
      )
    }
    return (
      <InlineError
        title="Couldn’t load your world"
        description={error instanceof Error ? error.message : undefined}
        onRetry={() => void world.refetch()}
      />
    )
  }
  const graph = world.data
  if (!graph || !graph.bank_available || graph.nodes.length === 0) {
    return (
      <div className="rounded-2xl border border-flat-border bg-flat-surface">
        <EmptyState
          icon={<Network />}
          title="Your world is still forming"
          body="As conversations mention people, places and things, your assistant builds a picture of each and how they connect. It appears here."
          action={{ label: 'Talk with your assistant', onClick: () => onDiscuss() }}
        />
      </div>
    )
  }
  return (
    <div className="flex flex-col gap-3">
      <WorldGraph graph={graph} onDiscuss={onDiscuss} />
      {error && (
        <InlineError title="Some of your world didn’t refresh" description={error instanceof Error ? error.message : undefined} onRetry={() => void world.refetch()} />
      )}
      <div className="flex flex-col gap-1 px-1">
        <p className="text-2xs text-flat-muted-fg">From your assistant’s memory. Types and details can change as more context is learned.</p>
        {graph.retrieved_at && <p className="text-2xs text-flat-subtle-fg">Checked {formatDateTime(graph.retrieved_at)}</p>}
      </div>
    </div>
  )
}
