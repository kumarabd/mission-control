import { Link, useLocation, useParams, useSearchParams } from 'react-router-dom'
import { ChevronLeft, UserRound } from 'lucide-react'
import { EmptyState, Skeleton } from '../components/ui'
import Screen from '../components/mission/Screen'
import InlineError from '../components/mission/InlineError'
import ListCard from '../components/mission/ListCard'
import { formatDateTime } from '../lib/life'
import { useEntityMemoryFacts } from '../lib/semanticMemory'
import type { MemoryFactItem } from '../lib/types'

function networkLabel(network: string): string {
  if (network === 'observation') return 'Observation'
  if (network === 'experience') return 'Experience'
  return 'Fact'
}

export default function MemoryEntity() {
  const { entityId = '' } = useParams()
  const [params] = useSearchParams()
  const location = useLocation()
  const stateEntity = (location.state as { entity?: { id: string; name: string } } | null)?.entity
  const name = stateEntity?.id === entityId ? stateEntity.name : params.get('name') || 'Related context'
  const facts = useEntityMemoryFacts(entityId)

  const back = (
    <Link
      to="/memory"
      className="inline-flex items-center gap-1 text-flat-muted-fg hover:text-flat-foreground"
    >
      <ChevronLeft className="size-3.5" aria-hidden />
      Memory
    </Link>
  )

  return (
    <Screen eyebrow={back} title={name} description="What your assistant connects to this.">
      {facts.isPending ? (
        <div className="rounded-2xl border border-flat-border bg-flat-surface p-4" aria-busy="true">
          <div className="flex flex-col gap-4">
            {Array.from({ length: 3 }).map((_, index) => (
              <div key={index}>
                <Skeleton className="h-3 w-16" />
                <Skeleton className="mt-2 h-4 w-full" />
              </div>
            ))}
          </div>
        </div>
      ) : facts.isError ? (
        <InlineError
          title="Couldn’t load related memory"
          description={facts.error instanceof Error ? facts.error.message : undefined}
          onRetry={() => void facts.refetch()}
        />
      ) : facts.data.items.length === 0 ? (
        <div className="rounded-2xl border border-flat-border bg-flat-surface">
          <EmptyState
            icon={<UserRound />}
            title={facts.data.bank_available ? 'Nothing remembered yet' : 'Your memory isn’t ready here yet'}
            body={
              facts.data.bank_available
                ? `Your assistant hasn’t connected ${name} to anything else yet.`
                : 'Your assistant’s remembered context will appear here as it develops.'
            }
          />
        </div>
      ) : (
        <div className="mx-auto flex w-full max-w-3xl flex-col gap-2">
          <ListCard>
            {facts.data.items.map((fact: MemoryFactItem) => (
              <div
                key={fact.id}
                className="border-b border-flat-border px-4 py-3 last:border-b-0"
              >
                <p className="font-mono text-2xs uppercase tracking-[0.12em] text-flat-primary">
                  {networkLabel(fact.network)}
                </p>
                <p className="mt-1 text-native-callout text-flat-foreground">{fact.text}</p>
                {fact.mention_time && (
                  <p className="mt-1 text-2xs text-flat-muted-fg">
                    {formatDateTime(fact.mention_time)}
                  </p>
                )}
              </div>
            ))}
          </ListCard>
          {facts.data.has_more && (
            <p className="px-1 text-2xs text-flat-muted-fg">
              Showing the most recent memory connected to {name}.
            </p>
          )}
        </div>
      )}
    </Screen>
  )
}
