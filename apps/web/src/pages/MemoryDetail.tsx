import { Link, useLocation, useNavigate, useParams } from 'react-router-dom'
import {
  ChevronLeft,
  ChevronRight,
  FileText,
  MessageSquare,
  Sparkles,
} from 'lucide-react'
import { Button, EmptyState } from '../components/ui'
import Screen from '../components/mission/Screen'
import ListCard from '../components/mission/ListCard'
import Markdown from '../components/mission/Markdown'
import { useChatDraft } from '../lib/chatDraft'
import { formatDateTime } from '../lib/life'
import { readCachedSemanticItem } from '../lib/semanticCache'
import { semanticKindLabel } from '../lib/semanticMemory'
import type { SemanticMemoryItem } from '../lib/types'

export default function MemoryDetail() {
  const { itemKey = '' } = useParams()
  const location = useLocation()
  const navigate = useNavigate()
  const requestDraft = useChatDraft((state) => state.request)
  const fromState = (location.state as { item?: SemanticMemoryItem } | null)?.item
  const item = fromState && fromState.id === itemKey ? fromState : readCachedSemanticItem(itemKey)

  const back = (
    <Link
      to="/memory"
      className="inline-flex items-center gap-1 text-flat-muted-fg hover:text-flat-foreground"
    >
      <ChevronLeft className="size-3.5" aria-hidden />
      Memory
    </Link>
  )

  if (!item) {
    return (
      <Screen eyebrow={back} title="Memory">
        <EmptyState
          icon={<Sparkles />}
          title="This insight isn’t loaded"
          body="Open Memory to browse what your assistant remembers, then choose the insight from there."
          action={{ label: 'Back to memory', to: '/memory' }}
        />
      </Screen>
    )
  }

  const discuss = () => {
    requestDraft(`About memory item ${item.id}, ‘${item.title}’: `)
    navigate('/chat')
  }

  const sourceNote =
    item.source_status === 'not_recorded'
      ? 'Source links weren’t saved with this insight. Related context names describe associations, not supporting evidence.'
      : 'These memories informed the document. They aren’t citations for individual claims.'

  return (
    <Screen
      eyebrow={back}
      title={item.title}
      description={`${semanticKindLabel(item.kind)}${
        item.updated_at ? ` · Updated ${formatDateTime(item.updated_at)}` : ''
      }`}
    >
      <div className="mx-auto flex w-full max-w-3xl flex-col gap-5">
        <div>
          <p className="font-mono text-2xs uppercase tracking-[0.12em] text-flat-primary">
            {semanticKindLabel(item.kind)}
          </p>
          {item.content ? (
            <Markdown className="mt-2">{item.content}</Markdown>
          ) : (
            <p className="mt-2 text-native-body text-flat-muted-fg">
              A summary isn’t available yet. Your assistant updates understanding as new context is
              retained.
            </p>
          )}
          {item.truncated && (
            <p className="mt-2 text-2xs text-flat-muted-fg">This is a shortened view of this item.</p>
          )}
          {(item.availability === 'partial' || item.availability === 'unavailable') && (
            <p className="mt-2 text-2xs text-flat-muted-fg">
              {item.availability === 'partial'
                ? 'This view is partial; part of the underlying memory is still being prepared.'
                : 'This understanding isn’t available in full right now.'}
            </p>
          )}
        </div>

        {item.entities.length > 0 && (
          <section aria-labelledby="memory-related">
            <h2
              id="memory-related"
              className="mb-2 text-native-callout font-medium text-flat-foreground"
            >
              Related context
            </h2>
            <ListCard>
              {item.entities.map((entity) => (
                <button
                  key={entity.id}
                  type="button"
                  onClick={() =>
                    navigate(
                      `/memory/entity/${encodeURIComponent(entity.id)}?name=${encodeURIComponent(entity.name)}`,
                      { state: { entity } },
                    )
                  }
                  className="flex min-h-11 w-full items-center gap-3 border-b border-flat-border px-4 py-2.5 text-left text-native-callout text-flat-foreground last:border-b-0 hover:bg-flat-muted focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-flat-primary"
                >
                  <span className="min-w-0 flex-1 truncate">{entity.name}</span>
                  <ChevronRight className="size-4 shrink-0 text-flat-border-strong" aria-hidden />
                </button>
              ))}
            </ListCard>
          </section>
        )}

        <details className="rounded-2xl border border-flat-border bg-flat-surface">
          <summary className="flex min-h-11 cursor-pointer items-center px-4 text-native-callout font-medium text-flat-foreground">
            About this insight
          </summary>
          <p className="border-t border-flat-border px-4 py-3 text-sm text-flat-muted-fg">
            {sourceNote}
          </p>
        </details>

        {item.sources && item.sources.length > 0 && (
          <section aria-labelledby="memory-sources">
            <h2
              id="memory-sources"
              className="mb-2 text-native-callout font-medium text-flat-foreground"
            >
              Supporting memory
            </h2>
            <ListCard>
              {item.sources.map((source) =>
                source.available ? (
                  <button
                    key={source.id}
                    type="button"
                    onClick={() =>
                      navigate(
                        `/memory/${encodeURIComponent(item.id)}/source/${encodeURIComponent(source.id)}`,
                        { state: { source, item } },
                      )
                    }
                    className="flex min-h-11 w-full items-center gap-3 border-b border-flat-border px-4 py-2.5 text-left text-native-callout text-flat-foreground last:border-b-0 hover:bg-flat-muted focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-flat-primary"
                  >
                    <FileText className="size-4 shrink-0 text-flat-muted-fg" aria-hidden />
                    <span className="min-w-0 flex-1 truncate">{source.title}</span>
                    <ChevronRight className="size-4 shrink-0 text-flat-border-strong" aria-hidden />
                  </button>
                ) : (
                  <div
                    key={source.id}
                    className="flex min-h-11 items-center gap-3 border-b border-flat-border px-4 py-2.5 text-native-callout text-flat-muted-fg last:border-b-0"
                  >
                    <FileText className="size-4 shrink-0" aria-hidden />
                    <span className="min-w-0 flex-1">Source unavailable</span>
                  </div>
                ),
              )}
            </ListCard>
          </section>
        )}

        <div>
          <Button
            variant="secondary"
            size="touch"
            onClick={discuss}
            iconLeft={<MessageSquare className="size-4" aria-hidden />}
          >
            Discuss or correct this
          </Button>
          <p className="mt-2 text-2xs text-flat-muted-fg">
            Requests go to your assistant. This view updates when memory has actually refreshed.
          </p>
        </div>
      </div>
    </Screen>
  )
}
