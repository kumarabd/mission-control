import { Link, useLocation, useParams } from 'react-router-dom'
import { ChevronLeft, FileText } from 'lucide-react'
import { EmptyState, Skeleton } from '../components/ui'
import Screen from '../components/mission/Screen'
import InlineError from '../components/mission/InlineError'
import Markdown from '../components/mission/Markdown'
import { ApiError } from '../lib/api'
import { formatDateTime } from '../lib/life'
import { useSemanticSource } from '../lib/semanticMemory'
import type { SemanticMemoryItem, SemanticSourceRef } from '../lib/types'

export default function MemorySource() {
  const { itemKey = '', sourceId = '' } = useParams()
  const location = useLocation()
  const state = location.state as
    | { source?: SemanticSourceRef; item?: SemanticMemoryItem }
    | null
  const source = state?.source
  const parent = state?.item
  const read = useSemanticSource(itemKey, sourceId)
  const item = read.data
  const title = source?.title || item?.title || 'Supporting memory'

  const back = (
    <Link
      to={`/memory/${encodeURIComponent(itemKey)}`}
      state={parent ? { item: parent } : undefined}
      className="inline-flex items-center gap-1 text-flat-muted-fg hover:text-flat-foreground"
    >
      <ChevronLeft className="size-3.5" aria-hidden />
      {parent ? parent.title : 'Memory'}
    </Link>
  )

  const unavailable =
    read.error instanceof ApiError && (read.error.status === 404 || read.error.status === 410)

  return (
    <Screen eyebrow={back} title={title}>
      {read.isPending ? (
        <div className="mx-auto flex w-full max-w-3xl flex-col gap-3" aria-busy="true">
          <Skeleton className="h-4 w-32" />
          <Skeleton className="h-4 w-full" />
          <Skeleton className="h-4 w-5/6" />
          <Skeleton className="h-4 w-2/3" />
        </div>
      ) : unavailable ? (
        <EmptyState
          icon={<FileText />}
          title="This supporting memory is no longer available"
          body="It may have been removed or replaced since this insight was written."
          action={{ label: 'Back to the insight', to: `/memory/${encodeURIComponent(itemKey)}` }}
        />
      ) : read.isError ? (
        <InlineError
          title="Couldn’t load this source"
          description={read.error instanceof Error ? read.error.message : undefined}
          onRetry={() => void read.refetch()}
        />
      ) : item ? (
        <article className="mx-auto w-full max-w-3xl">
          {item.updated_at && (
            <p className="mb-2 text-2xs text-flat-muted-fg">
              {formatDateTime(item.updated_at)}
            </p>
          )}
          {item.content ? (
            <Markdown>{item.content}</Markdown>
          ) : (
            <p className="text-native-body text-flat-muted-fg">No readable content is available.</p>
          )}
          {item.truncated && (
            <p className="mt-3 text-2xs text-flat-muted-fg">This is a shortened view.</p>
          )}
          <p className="mt-6 text-2xs text-flat-muted-fg">
            Read-only. This memory informed the insight above; it isn’t a citation for individual
            claims.
          </p>
        </article>
      ) : null}
    </Screen>
  )
}
