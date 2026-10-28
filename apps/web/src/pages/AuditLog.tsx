import { useMemo, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { ScrollText } from 'lucide-react'
import EmptyState from '../components/ui/EmptyState'
import PageHeader from '../components/ui/PageHeader'
import { cn } from '../lib/cn'
import { getAudit } from '../lib/api'
import type { AuditEntry } from '../lib/types'

/** Plain-language names for the operations the memory service records. */
const OPERATION_LABEL: Record<string, string> = {
  memory_write: 'Remembered something',
  memory_retain: 'Remembered something',
  tool_call: 'Used a tool',
  approval_granted: 'You approved a request',
  approval_denied: 'You declined a request',
  consolidation: 'Tidied up its memory',
  supersede: 'Updated an earlier memory',
  contradiction_resolve: 'Resolved a conflicting memory',
}

const humanize = (op: string) =>
  OPERATION_LABEL[op] ?? op.replace(/[_-]+/g, ' ').replace(/^\w/, (c) => c.toUpperCase())

function dayLabel(iso: string): string {
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return 'Earlier'
  const startOf = (x: Date) => new Date(x.getFullYear(), x.getMonth(), x.getDate()).getTime()
  const diff = Math.round((startOf(new Date()) - startOf(d)) / 86_400_000)
  if (diff === 0) return 'Today'
  if (diff === 1) return 'Yesterday'
  return d.toLocaleDateString(undefined, { weekday: 'long', month: 'short', day: 'numeric' })
}

const timeLabel = (iso: string) => {
  const d = new Date(iso)
  return Number.isNaN(d.getTime()) ? '' : d.toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' })
}

function Chip({ active, onClick, children }: { active?: boolean; onClick: () => void; children: React.ReactNode }) {
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

function Event({ entry, last }: { entry: AuditEntry; last: boolean }) {
  const [open, setOpen] = useState(false)
  const meta = [entry.agent_id && `agent ${entry.agent_id}`, entry.session_id && `session ${entry.session_id.slice(0, 8)}`]
    .filter(Boolean)
    .join(' · ')
  return (
    <li className="relative grid grid-cols-[4.6rem_0.9rem_minmax(0,1fr)] gap-x-3 py-2">
      {!last && <span className="absolute bottom-[-0.5rem] left-[5.85rem] top-6 w-px bg-flat-border" aria-hidden />}
      <span className="whitespace-nowrap pt-0.5 text-right font-mono text-xs text-flat-subtle-fg">{timeLabel(entry.created_at)}</span>
      <span className="mt-2 size-2 place-self-start justify-self-center rounded-full bg-flat-primary" aria-hidden />
      <div className="min-w-0">
        <button
          type="button"
          onClick={() => setOpen((o) => !o)}
          aria-expanded={open}
          className="text-left text-base text-flat-foreground transition-colors hover:text-flat-primary"
        >
          {humanize(entry.operation)}
        </button>
        {meta && <p className="font-mono text-xs text-flat-subtle-fg">{meta}</p>}
        {open && (
          <pre className="mt-2 overflow-x-auto rounded-lg bg-flat-tint-soft px-3 py-2.5 font-mono text-xs leading-relaxed text-flat-muted-fg">
            {JSON.stringify(entry, null, 2)}
          </pre>
        )}
      </div>
    </li>
  )
}

export default function AuditLog() {
  const [operation, setOperation] = useState('all')
  const audit = useQuery({ queryKey: ['audit'], queryFn: () => getAudit(), refetchInterval: 10_000 })
  const items = useMemo(() => audit.data?.items ?? [], [audit.data])

  const operations = useMemo(() => {
    const counts = new Map<string, number>()
    items.forEach((e) => counts.set(e.operation, (counts.get(e.operation) ?? 0) + 1))
    return [...counts.entries()].sort((a, b) => b[1] - a[1]).slice(0, 6).map(([op]) => op)
  }, [items])

  const days = useMemo(() => {
    const shown = items.filter((e) => operation === 'all' || e.operation === operation)
    const groups = new Map<string, AuditEntry[]>()
    shown.forEach((e) => {
      const k = dayLabel(e.created_at)
      groups.set(k, [...(groups.get(k) ?? []), e])
    })
    return [...groups.entries()]
  }, [items, operation])

  return (
    <div>
      <PageHeader title="Activity" description="A plain record of what your assistant did, learned and asked you. Select an entry for the raw detail." />

      {operations.length > 0 && (
        <div className="mb-2 flex flex-wrap items-center gap-2">
          <Chip active={operation === 'all'} onClick={() => setOperation('all')}>
            All
          </Chip>
          {operations.map((op) => (
            <Chip key={op} active={operation === op} onClick={() => setOperation(op)}>
              {humanize(op)}
            </Chip>
          ))}
        </div>
      )}

      {audit.isError && (
        <EmptyState size="sm" title="Couldn't load activity" action={{ label: 'Retry', onClick: () => audit.refetch() }} />
      )}
      {!audit.isLoading && !audit.isError && days.length === 0 && (
        <EmptyState size="sm" icon={<ScrollText />} title="No activity yet" body="Entries appear as your assistant works." />
      )}

      {days.map(([day, entries]) => (
        <section key={day}>
          <h2 className="mb-1 mt-7 font-mono text-xs uppercase tracking-wide text-flat-subtle-fg">{day}</h2>
          <ul>
            {entries.map((e, i) => (
              <Event key={e.id} entry={e} last={i === entries.length - 1} />
            ))}
          </ul>
        </section>
      ))}
    </div>
  )
}
