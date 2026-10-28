import { useMemo, useState } from 'react'
import { useLocation, useNavigate } from 'react-router-dom'
import { useQuery, keepPreviousData } from '@tanstack/react-query'
import * as Dialog from '@radix-ui/react-dialog'
import { Search, X } from 'lucide-react'
import Button from '../components/ui/Button'
import EmptyState from '../components/ui/EmptyState'
import PageHeader from '../components/ui/PageHeader'
import { cn } from '../lib/cn'
import { getMemoryFacts, getMemoryUnitLinks, getRawTableRows } from '../lib/api'
import { formatDateTime, formatRelative } from '../lib/format'

const PAGE_SIZE = 50

type Tab = 'memory_unit' | 'entity' | 'mental_model'
type Row = Record<string, unknown>

const ROUTE: Record<Tab, string> = {
  memory_unit: '/memory/units',
  entity: '/memory/entities',
  mental_model: '/memory/mental-models',
}

const HEADING: Record<Tab, { title: string; description: string }> = {
  memory_unit: { title: 'Memories', description: 'What your assistant remembers about you, and where each memory came from.' },
  entity: { title: 'People & things', description: 'The people, places and things your assistant keeps track of.' },
  mental_model: { title: 'Patterns', description: 'What your assistant has noticed about how you like to do things.' },
}

const TAB_FROM_PATH: Record<string, Tab> = {
  '/memory/entities': 'entity',
  '/memory/mental-models': 'mental_model',
}

/** Plain-language names for the memory networks. */
const NETWORKS: { id: string; label: string }[] = [
  { id: 'world', label: 'Facts' },
  { id: 'experience', label: 'From conversations' },
  { id: 'observation', label: 'Noticed' },
]
const networkLabel = (id: string) => NETWORKS.find((n) => n.id === id)?.label ?? id

const EMPTY_COPY: Record<Tab, { title: string; body: string }> = {
  memory_unit: { title: 'Nothing remembered yet', body: 'Memories appear here as you talk to your assistant.' },
  entity: { title: 'No people or things yet', body: 'They appear as conversations mention people, places and things.' },
  mental_model: { title: 'No patterns yet', body: 'Patterns appear once your assistant has noticed enough about how you work.' },
}

const str = (row: Row, key: string): string => (typeof row[key] === 'string' ? (row[key] as string) : '')
const strs = (row: Row, key: string): string[] =>
  Array.isArray(row[key]) ? (row[key] as unknown[]).filter((x): x is string => typeof x === 'string') : []
const num = (row: Row, key: string): number | null => (typeof row[key] === 'number' ? (row[key] as number) : null)

function titleOf(row: Row, tab: Tab): string {
  if (tab === 'memory_unit') return str(row, 'text') || 'Memory'
  if (tab === 'entity') return str(row, 'canonical_name') || 'Unnamed'
  return str(row, 'name') || str(row, 'id')
}

function Meter({ value }: { value: number }) {
  return (
    <span className="block h-[5px] w-[72px] overflow-hidden rounded-full bg-flat-border" title={`${Math.round(value * 100)}% sure`}>
      <i className="block h-full rounded-full bg-flat-primary" style={{ width: `${Math.round(value * 100)}%` }} />
    </span>
  )
}

function Chip({ active, onClick, children }: { active?: boolean; onClick?: () => void; children: React.ReactNode }) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-pressed={active}
      className={cn(
        'rounded-full border px-3 py-1 font-mono text-xs transition-colors',
        active
          ? 'border-flat-primary bg-flat-tint text-flat-foreground'
          : 'border-flat-border text-flat-muted-fg hover:border-flat-primary hover:text-flat-foreground',
      )}
    >
      {children}
    </button>
  )
}

function ListRow({ row, tab, onOpen }: { row: Row; tab: Tab; onOpen: () => void }) {
  const confidence = num(row, 'confidence')
  const when =
    tab === 'memory_unit' ? str(row, 'mention_time') : tab === 'entity' ? str(row, 'last_mentioned_at') : str(row, 'last_refreshed_at')
  const sub =
    tab === 'memory_unit'
      ? [networkLabel(str(row, 'network')), str(row, 'id').slice(0, 8)].filter(Boolean).join(' · ')
      : tab === 'entity'
        ? strs(row, 'aliases').join(', ') || 'No other names'
        : str(row, 'source_query')
  return (
    <button
      type="button"
      onClick={onOpen}
      className="grid w-full grid-cols-[minmax(0,1fr)_auto] items-center gap-x-4 gap-y-0.5 border-b border-flat-border px-5 py-3.5 text-left transition-colors last:border-b-0 hover:bg-flat-tint-soft"
    >
      <span className="line-clamp-2 text-base text-flat-foreground sm:truncate">{titleOf(row, tab)}</span>
      <span className="flex items-center gap-3">
        {confidence != null && (
          <span className="hidden sm:block">
            <Meter value={confidence} />
          </span>
        )}
        <span className="font-mono text-xs text-flat-subtle-fg">{when ? formatRelative(when) : '—'}</span>
      </span>
      <span className="truncate font-mono text-xs text-flat-subtle-fg">{sub}</span>
    </button>
  )
}

/** Remaining scalar columns, shown honestly as they are stored. */
function Details({ row, skip }: { row: Row; skip: string[] }) {
  const entries = Object.entries(row).filter(
    ([k, v]) => !skip.includes(k) && v != null && v !== '' && (typeof v === 'string' || typeof v === 'number' || typeof v === 'boolean'),
  )
  if (!entries.length) return null
  return (
    <dl className="mt-1 grid grid-cols-[auto_minmax(0,1fr)] gap-x-4 gap-y-1.5 font-mono text-xs">
      {entries.map(([k, v]) => (
        <div key={k} className="contents">
          <dt className="text-flat-subtle-fg">{k}</dt>
          <dd className="truncate text-flat-muted-fg" title={String(v)}>
            {String(v)}
          </dd>
        </div>
      ))}
    </dl>
  )
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="mt-6">
      <p className="mb-1.5 font-mono text-xs uppercase tracking-wide text-flat-subtle-fg">{title}</p>
      {children}
    </div>
  )
}

/** Entity-joined facts (GET /v1/explorer/memory/facts?entity_id=) — a purpose-built
 * drill-down distinct from the raw /raw/memory_unit browser the primary list uses. */
function EntityConnectedFacts({ entityId }: { entityId: string }) {
  const q = useQuery({
    queryKey: ['memory-entity-facts', entityId],
    queryFn: () => getMemoryFacts({ entityId, limit: 10 }),
    enabled: Boolean(entityId),
  })
  if (q.isLoading) return <p className="text-sm text-flat-muted-fg">Loading…</p>
  if (q.isError) return <p className="text-sm text-flat-muted-fg">Couldn't load connected facts.</p>
  const items = q.data?.items ?? []
  if (!items.length) return <p className="text-sm text-flat-muted-fg">Nothing connected yet.</p>
  return (
    <ul className="space-y-2.5">
      {items.map((item) => (
        <li key={item.id} className="text-sm text-flat-foreground">
          <span className="mr-2 rounded-full border border-flat-border px-2 py-0.5 font-mono text-[11px] text-flat-muted-fg">
            {networkLabel(item.network)}
          </span>
          {item.text}
          {item.mention_time && (
            <span className="ml-2 font-mono text-xs text-flat-subtle-fg">{formatRelative(item.mention_time)}</span>
          )}
        </li>
      ))}
    </ul>
  )
}

/** One memory unit's persisted memory_link edges plus live entity-derived
 * adjacency (GET /v1/explorer/memory/units/{id}/links). */
function MemoryUnitConnectedLinks({ unitId }: { unitId: string }) {
  const q = useQuery({
    queryKey: ['memory-unit-links', unitId],
    queryFn: () => getMemoryUnitLinks(unitId),
    enabled: Boolean(unitId),
  })
  if (q.isLoading) return <p className="text-sm text-flat-muted-fg">Loading…</p>
  if (q.isError) return <p className="text-sm text-flat-muted-fg">Couldn't load connections.</p>
  const links = q.data?.links ?? []
  if (!links.length) return <p className="text-sm text-flat-muted-fg">Nothing connected yet.</p>
  return (
    <ul className="space-y-2.5">
      {links.map((link, i) => (
        <li key={`${link.id}-${i}`} className="text-sm text-flat-foreground">
          <span className="mr-2 rounded-full border border-flat-border px-2 py-0.5 font-mono text-[11px] text-flat-muted-fg">
            {link.link_type}
            {link.direction ? ` · ${link.direction}` : ''}
          </span>
          {link.text}
        </li>
      ))}
    </ul>
  )
}

function DrawerBody({ row, tab }: { row: Row; tab: Tab }) {
  const confidence = num(row, 'confidence')
  return (
    <>
      <Dialog.Title className="mt-3 text-2xl font-normal leading-snug tracking-tight text-flat-foreground">
        {titleOf(row, tab)}
      </Dialog.Title>
      <Dialog.Description className="sr-only">Details about this item.</Dialog.Description>

      {tab === 'memory_unit' && (
        <>
          {confidence != null && (
            <Section title="How sure it is">
              <div className="flex items-center gap-3">
                <Meter value={confidence} />
                <span className="text-sm">{Math.round(confidence * 100)}%</span>
              </div>
            </Section>
          )}
          <Section title="When">
            <p className="text-sm text-flat-foreground">
              Remembered {formatDateTime(str(row, 'mention_time'))}
              <span className="text-flat-muted-fg"> ({formatRelative(str(row, 'mention_time'))})</span>
            </p>
          </Section>
          <Section title="Connected memories">
            <MemoryUnitConnectedLinks unitId={str(row, 'id')} />
          </Section>
        </>
      )}

      {tab === 'entity' && (
        <>
          <Section title="Also known as">
            <div className="flex flex-wrap gap-1.5">
              {strs(row, 'aliases').length ? (
                strs(row, 'aliases').map((a) => (
                  <span key={a} className="rounded-full bg-flat-tint px-2.5 py-0.5 text-sm text-flat-muted-fg">
                    {a}
                  </span>
                ))
              ) : (
                <span className="text-sm text-flat-muted-fg">No other names yet.</span>
              )}
            </div>
          </Section>
          <Section title="Last mentioned">
            <p className="text-sm text-flat-foreground">{formatDateTime(str(row, 'last_mentioned_at')) || 'Never'}</p>
          </Section>
          <Section title="Connected facts">
            <EntityConnectedFacts entityId={str(row, 'id')} />
          </Section>
        </>
      )}

      {tab === 'mental_model' && (
        <>
          {str(row, 'source_query') && (
            <Section title="Asked">
              <p className="text-sm italic text-flat-muted-fg">“{str(row, 'source_query')}”</p>
            </Section>
          )}
          <Section title="What it has learned">
            <p className="whitespace-pre-wrap text-base leading-relaxed text-flat-foreground">
              {str(row, 'content') || 'Nothing yet.'}
            </p>
          </Section>
        </>
      )}

      <Section title="Details">
        <Details
          row={row}
          skip={['text', 'canonical_name', 'name', 'content', 'source_query', 'aliases', 'confidence', 'network']}
        />
      </Section>

      <div className="mt-8 flex gap-2.5">
        <Button variant="outline" disabled title="Coming soon">
          Edit
        </Button>
        <Button variant="outline" disabled title="Coming soon">
          Forget
        </Button>
      </div>
      <p className="mt-2.5 font-mono text-xs text-flat-subtle-fg">Editing and forgetting are coming soon.</p>
    </>
  )
}

function DetailDrawer({ row, tab, onClose }: { row: Row | null; tab: Tab; onClose: () => void }) {
  return (
    <Dialog.Root open={row != null} onOpenChange={(open) => !open && onClose()}>
      <Dialog.Portal>
        <Dialog.Overlay
          className="fixed inset-0 z-40 bg-flat-foreground/30"
        />
        <Dialog.Content
          className="fixed inset-y-0 right-0 z-50 w-[min(440px,100vw)] overflow-y-auto border-l border-flat-border bg-flat-background p-6 outline-none"
        >
          <div className="flex items-center justify-between">
            <span className="rounded-full border border-flat-border px-2.5 py-0.5 font-mono text-xs text-flat-muted-fg">
              {tab === 'memory_unit' ? networkLabel(row ? str(row, 'network') : '') || 'Memory' : tab === 'entity' ? 'Person or thing' : 'Pattern'}
            </span>
            <Dialog.Close
              aria-label="Close"
              className="grid size-8 place-items-center rounded-md text-flat-muted-fg transition-colors hover:bg-flat-muted hover:text-flat-foreground"
            >
              <X className="size-4" />
            </Dialog.Close>
          </div>
          {row && <DrawerBody row={row} tab={tab} />}
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  )
}

export default function Memory() {
  const location = useLocation()
  const legacyTab = new URLSearchParams(location.search).get('tab') as Tab | null
  const tab = TAB_FROM_PATH[location.pathname] ?? legacyTab ?? 'memory_unit'
  // Keyed by section so search, filters and the open drawer reset when you switch.
  return <MemorySection key={tab} tab={tab} />
}

function MemorySection({ tab }: { tab: Tab }) {
  const location = useLocation()
  const navigate = useNavigate()
  const searchParams = new URLSearchParams(location.search)
  const offset = Math.max(0, Number(searchParams.get('offset') ?? 0) || 0)
  const [q, setQ] = useState('')
  const [network, setNetwork] = useState<string>('all')
  const [selected, setSelected] = useState<Row | null>(null)

  const rows = useQuery({
    queryKey: ['memory-rows', tab, offset],
    queryFn: () => getRawTableRows(tab, { limit: PAGE_SIZE, offset }),
    placeholderData: keepPreviousData,
  })

  function updateOffset(next: number) {
    const params = new URLSearchParams(searchParams)
    params.delete('tab')
    if (next <= 0) params.delete('offset')
    else params.set('offset', String(next))
    const query = params.toString()
    navigate(`${ROUTE[tab]}${query ? `?${query}` : ''}`, { replace: true })
  }

  const items = useMemo(() => rows.data?.items ?? [], [rows.data])
  const shown = useMemo(() => {
    const needle = q.trim().toLowerCase()
    return items.filter((r) => {
      if (tab === 'memory_unit' && network !== 'all' && str(r, 'network') !== network) return false
      return !needle || JSON.stringify(Object.values(r)).toLowerCase().includes(needle)
    })
  }, [items, q, network, tab])
  const hasNextPage = items.length === PAGE_SIZE

  return (
    <div>
      <PageHeader title={HEADING[tab].title} description={HEADING[tab].description} />

      <div className="mb-3.5 flex flex-wrap items-center gap-2">
        <label className="flex h-9 min-w-56 items-center gap-2 rounded-full border border-flat-border bg-flat-surface px-3.5 focus-within:border-flat-primary">
          <Search className="size-4 text-flat-subtle-fg" />
          <input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="Search this page"
            aria-label="Search"
            className="min-w-0 flex-1 bg-transparent text-sm outline-none placeholder:text-flat-subtle-fg"
          />
        </label>
        {tab === 'memory_unit' && (
          <>
            <Chip active={network === 'all'} onClick={() => setNetwork('all')}>
              All
            </Chip>
            {NETWORKS.map((n) => (
              <Chip key={n.id} active={network === n.id} onClick={() => setNetwork(n.id)}>
                {n.label}
              </Chip>
            ))}
          </>
        )}
      </div>

      {rows.isError && (
        <EmptyState size="sm" title="Couldn't load this" body={String(rows.error)} action={{ label: 'Retry', onClick: () => rows.refetch() }} />
      )}
      {!rows.isError && rows.isLoading && <p className="text-sm text-flat-muted-fg">Loading…</p>}
      {!rows.isError && !rows.isLoading && items.length === 0 && <EmptyState {...EMPTY_COPY[tab]} />}
      {!rows.isError && items.length > 0 && (
        <div className="overflow-hidden rounded-2xl border border-flat-border bg-flat-surface">
          {shown.length ? (
            shown.map((row, i) => <ListRow key={str(row, 'id') || i} row={row} tab={tab} onOpen={() => setSelected(row)} />)
          ) : (
            <p className="px-5 py-8 text-center text-sm text-flat-muted-fg">Nothing matches.</p>
          )}
        </div>
      )}

      {items.length > 0 && (
        <div className="mt-4 flex items-center justify-between">
          <p className="font-mono text-xs text-flat-subtle-fg">
            Showing {offset + 1}–{offset + items.length}
          </p>
          <div className="flex gap-2">
            <Button variant="outline" disabled={offset === 0} onClick={() => updateOffset(offset - PAGE_SIZE)}>
              Previous
            </Button>
            <Button variant="outline" disabled={!hasNextPage} onClick={() => updateOffset(offset + PAGE_SIZE)}>
              Next
            </Button>
          </div>
        </div>
      )}

      <DetailDrawer row={selected} tab={tab} onClose={() => setSelected(null)} />
    </div>
  )
}
