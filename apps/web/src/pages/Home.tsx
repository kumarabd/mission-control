import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Link, useNavigate } from 'react-router-dom'
import { AlertTriangle, ArrowRight, Check, ScrollText } from 'lucide-react'
import { EmptyState, PageSkeleton } from '../components/ui'
import { getAudit, getOverview, getRawTableRows, getSystemStatus } from '../lib/api'
import { formatRelative } from '../lib/format'

/** Plain-language names for the memory networks. */
const NETWORK_LABEL: Record<string, string> = {
  world: 'Facts',
  experience: 'From conversations',
  observation: 'Noticed',
}
const NETWORK_COLOR: Record<string, string> = {
  world: 'bg-flat-success',
  experience: 'bg-flat-primary',
  observation: 'bg-flat-border-strong',
}

function greeting(): string {
  const h = new Date().getHours()
  if (h < 12) return 'Good morning.'
  if (h < 18) return 'Good afternoon.'
  return 'Good evening.'
}

function Section({
  title,
  action,
  children,
}: {
  title: string
  action?: { to: string; label: string }
  children: React.ReactNode
}) {
  return (
    <section className="mt-9">
      <div className="mb-3 flex items-baseline justify-between gap-4">
        <h2 className="text-lg font-medium tracking-tight">{title}</h2>
        {action && (
          <Link
            to={action.to}
            className="flex items-center gap-1 text-sm text-flat-muted-fg no-underline transition-colors hover:text-flat-foreground hover:no-underline"
          >
            {action.label}
            <ArrowRight className="size-3.5" />
          </Link>
        )}
      </div>
      {children}
    </section>
  )
}

function AskBox() {
  const navigate = useNavigate()
  const [value, setValue] = useState('')
  const submit = (e: React.FormEvent) => {
    e.preventDefault()
    navigate('/chat', { state: { prefill: value.trim() } })
  }
  return (
    <form
      onSubmit={submit}
      className="flex items-center gap-2 rounded-full border border-flat-border bg-flat-surface py-1.5 pl-5 pr-1.5 transition-[border-color,box-shadow] focus-within:border-flat-primary focus-within:shadow-[0_0_0_4px_var(--color-flat-tint)]"
    >
      <input
        value={value}
        onChange={(e) => setValue(e.target.value)}
        placeholder="Ask anything…"
        aria-label="Ask your assistant"
        className="h-10 min-w-0 flex-1 bg-transparent text-base outline-none placeholder:text-flat-subtle-fg"
      />
      <button
        type="submit"
        className="inline-flex h-10 items-center gap-2 rounded-full bg-flat-primary px-5 text-sm font-medium text-flat-on-primary transition-transform hover:bg-flat-primary-hover active:scale-[0.97]"
      >
        Ask
        <ArrowRight className="size-4" />
      </button>
    </form>
  )
}

function StatLink({ to, label, value }: { to: string; label: string; value: React.ReactNode }) {
  return (
    <Link
      to={to}
      className="block border-flat-border px-5 py-4 no-underline transition-colors hover:bg-flat-tint-soft hover:no-underline [&:not(:last-child)]:border-r max-sm:[&:nth-child(2)]:border-r-0 max-sm:[&:nth-child(-n+2)]:border-b"
    >
      <span className="block text-3xl font-light tabular-nums tracking-tight text-flat-foreground">{value}</span>
      <span className="font-mono text-xs text-flat-subtle-fg">{label}</span>
    </Link>
  )
}

export default function Home() {
  const overview = useQuery({ queryKey: ['overview'], queryFn: getOverview, refetchInterval: 20_000 })
  const status = useQuery({ queryKey: ['system-status'], queryFn: getSystemStatus, refetchInterval: 30_000 })
  const audit = useQuery({ queryKey: ['audit-home'], queryFn: () => getAudit(), refetchInterval: 20_000 })
  const recentMemory = useQuery({
    queryKey: ['memory-home'],
    queryFn: () => getRawTableRows('memory_unit', { limit: 6 }),
  })

  if (overview.isLoading) return <PageSkeleton />
  if (overview.error || !overview.data) {
    return (
      <EmptyState
        icon={<AlertTriangle />}
        title="Couldn't reach your assistant's memory"
        body="The memory service didn't respond. Check the deployment, then try again."
        action={{ label: 'Retry', onClick: () => overview.refetch() }}
      />
    )
  }

  const ov = overview.data
  const degraded = Object.entries(status.data?.degraded ?? {})
  const recentAudit = (audit.data?.items ?? []).slice(0, 6)
  const recentMemoryItems = recentMemory.data?.items ?? []
  const byNetwork = Object.entries(ov.memory_unit_by_network ?? {}).sort(([, a], [, b]) => b - a)
  const byNetworkTotal = byNetwork.reduce((s, [, n]) => s + n, 0)

  return (
    <div>
      <header className="mb-7">
        <h1 className="text-[clamp(1.9rem,3.4vw,2.6rem)] font-normal leading-[1.08] tracking-[-0.03em]">{greeting()}</h1>
        <p className="mt-2 text-base text-flat-muted-fg">Here is what your assistant is up to.</p>
      </header>

      <AskBox />

      <Section title="Needs you" action={degraded.length ? { to: '/metrics', label: 'Health' } : undefined}>
        <div
          className={`overflow-hidden rounded-2xl border bg-flat-surface ${degraded.length ? 'border-flat-warning/40' : 'border-flat-border'}`}
        >
          {degraded.length === 0 ? (
            <div className="grid justify-items-center gap-2 px-5 py-9 text-center text-flat-muted-fg">
              <span className="grid size-11 place-items-center rounded-full bg-flat-tint text-flat-primary">
                <Check className="size-5" />
              </span>
              <p className="font-medium text-flat-foreground">You’re all caught up</p>
              <p className="text-sm">Nothing needs you right now.</p>
            </div>
          ) : (
            <ul className="divide-y divide-flat-border">
              {degraded.map(([component, reason]) => (
                <li key={component}>
                  <Link
                    to="/metrics"
                    className="flex items-center gap-3 px-5 py-4 no-underline transition-colors hover:bg-flat-warning-muted hover:no-underline"
                  >
                    <span className="size-2 shrink-0 rounded-full bg-flat-warning" aria-hidden />
                    <span className="min-w-0 flex-1">
                      <span className="block font-medium text-flat-foreground">{component} needs a look</span>
                      <span className="block truncate text-sm text-flat-muted-fg">{reason}</span>
                    </span>
                    <ArrowRight className="size-4 text-flat-muted-fg" />
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </div>
      </Section>

      <Section title="Recently remembered" action={{ to: '/memory/units', label: 'All memory' }}>
        <div className="overflow-hidden rounded-2xl border border-flat-border bg-flat-surface">
          {recentMemoryItems.length === 0 ? (
            <EmptyState size="sm" title="Nothing remembered yet" body="Memories appear here as you talk to your assistant." />
          ) : (
            <ul className="divide-y divide-flat-border">
              {recentMemoryItems.map((row, i) => {
                const network = String(row.network ?? '')
                return (
                  <li key={String(row.id ?? i)}>
                    <Link
                      to="/memory/units"
                      className="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-x-4 gap-y-0.5 px-5 py-3.5 no-underline transition-colors hover:bg-flat-tint-soft hover:no-underline"
                    >
                      <span className="truncate text-base text-flat-foreground">{String(row.text ?? 'memory')}</span>
                      <span className="font-mono text-xs text-flat-subtle-fg">{formatRelative(String(row.mention_time ?? ''))}</span>
                      {network && (
                        <span className="font-mono text-xs text-flat-subtle-fg">{NETWORK_LABEL[network] ?? network}</span>
                      )}
                    </Link>
                  </li>
                )
              })}
            </ul>
          )}
        </div>
      </Section>

      {byNetwork.length > 0 && (
        <Section title="What it remembers" action={{ to: '/memory/units', label: 'Open memory' }}>
          <div className="rounded-2xl border border-flat-border bg-flat-surface p-5">
            <div className="flex h-2 overflow-hidden rounded-full bg-flat-muted">
              {byNetwork.map(([net, count]) => (
                <div
                  key={net}
                  className={NETWORK_COLOR[net] ?? 'bg-flat-subtle-fg'}
                  style={{ width: `${byNetworkTotal ? (count / byNetworkTotal) * 100 : 0}%` }}
                  title={`${NETWORK_LABEL[net] ?? net}: ${count}`}
                />
              ))}
            </div>
            <div className="mt-3 flex flex-wrap gap-x-5 gap-y-1.5">
              {byNetwork.map(([net, count]) => (
                <span key={net} className="flex items-center gap-1.5 text-sm text-flat-muted-fg">
                  <span className={`size-2 rounded-full ${NETWORK_COLOR[net] ?? 'bg-flat-subtle-fg'}`} />
                  {NETWORK_LABEL[net] ?? net}
                  <span className="font-mono tabular-nums text-flat-foreground">{count}</span>
                </span>
              ))}
            </div>
          </div>
        </Section>
      )}

      <Section title="Recent activity" action={{ to: '/advanced/audit', label: 'All activity' }}>
        <div className="overflow-hidden rounded-2xl border border-flat-border bg-flat-surface">
          {recentAudit.length === 0 ? (
            <EmptyState size="sm" icon={<ScrollText />} title="No activity yet" />
          ) : (
            <ul className="divide-y divide-flat-border">
              {recentAudit.map((entry) => (
                <li key={entry.id} className="flex items-center justify-between gap-4 px-5 py-3 text-sm">
                  <span className="min-w-0 truncate text-flat-foreground">{entry.operation.replace(/[_-]/g, ' ')}</span>
                  <span className="shrink-0 font-mono text-xs text-flat-subtle-fg">{formatRelative(entry.created_at)}</span>
                </li>
              ))}
            </ul>
          )}
        </div>
      </Section>

      <section className="mt-9 overflow-hidden rounded-2xl border border-flat-border bg-flat-surface">
        <div className="grid sm:grid-cols-4 max-sm:grid-cols-2">
          <StatLink to="/memory/units" label="memories" value={ov.memory_unit_count ?? '—'} />
          <StatLink to="/memory/entities" label="people & things" value={ov.entity_count ?? 0} />
          <StatLink to="/memory/mental-models" label="patterns" value={ov.mental_model_count ?? 0} />
          <StatLink
            to="/memory/units"
            label="since last memory"
            value={recentMemoryItems[0] ? formatRelative(String(recentMemoryItems[0].mention_time ?? '')) : '—'}
          />
        </div>
      </section>
    </div>
  )
}
