import { useEffect, useRef, useState, type FormEvent, type ReactNode } from 'react'
import { useQuery } from '@tanstack/react-query'
import { AlertTriangle, Download, ReceiptText, RefreshCw } from 'lucide-react'
import { Button, EmptyState, Input, PageSkeleton } from '../components/ui'
import { FinanceAuth } from '../finance/FinanceAuth'
import { FinanceError, type Bucket, type Directory, type Filter, type FinanceAPI, type Spend } from '../finance/api'
import { formatDate, formatMoney, monthWindow } from '../finance/format'

const panel = 'rounded-2xl border border-flat-border bg-flat-surface'
const selectStyle = 'h-9 w-full rounded-sm border border-flat-border bg-flat-surface px-2 text-sm text-flat-foreground'
const retry = (count: number, error: Error) => count < 1 && (!(error instanceof FinanceError) || error.status >= 500 || error.status === 429)

function FormField({ title, children }: { title: string; children: ReactNode }) {
  return <label className="flex min-w-0 flex-col gap-1.5 text-sm text-flat-muted-fg">{title}{children}</label>
}

function SpendRow({ spend, directory }: { spend: Spend; directory: Directory }) {
  const merchant = directory.merchants.find((d) => d.id === spend.merchant_id)?.name
  const title = merchant || spend.description || (spend.kind === 'refund' ? 'Refund' : spend.kind === 'transfer' ? 'Transfer' : 'Spend')
  return <li>
    <details className="group px-5 py-4">
      <summary className="flex cursor-pointer list-none items-center justify-between gap-4 rounded-sm focus-visible:outline-2 focus-visible:outline-flat-primary">
        <div className="min-w-0">
          <p className="truncate font-medium">{title}</p>
          <p className="mt-1 text-sm text-flat-muted-fg">{formatDate(spend.occurred_on)} · <span className="capitalize">{spend.kind}</span>{spend.kind === 'transfer' && ' · Excluded from totals'}</p>
        </div>
        <div className="shrink-0 text-right">
          <p className="font-mono text-sm tabular-nums">{spend.kind === 'refund' ? '−' : ''}{formatMoney(spend.amount_minor, spend.currency)}</p>
          <p className="mt-1 text-xs text-flat-subtle-fg group-open:hidden">View details</p>
        </div>
      </summary>
      <div className="mt-4 space-y-3 border-t border-flat-border pt-4 text-sm">
        {merchant && spend.description && <p className="break-words text-flat-muted-fg">{spend.description}</p>}
        <dl className="space-y-2">
          {(spend.allocations ?? []).map((a, i) => <div key={i} className="flex justify-between gap-4">
            <dt>{a.category_id ? directory.categories.find((c) => c.id === a.category_id)?.name || 'Category unavailable' : 'Uncategorized'}</dt>
            <dd className="font-mono tabular-nums">{formatMoney(a.amount_minor, spend.currency)}</dd>
          </div>)}
        </dl>
        {!!spend.tag_ids?.length && <p className="flex flex-wrap gap-2" aria-label="Tags">{spend.tag_ids.map((id) => <span key={id} className="rounded-full bg-flat-muted px-2.5 py-1">{directory.tags.find((t) => t.id === id)?.name || 'Tag unavailable'}</span>)}</p>}
        {spend.account_ref && <p className="break-words text-flat-muted-fg">Account: {spend.account_ref}</p>}
        {!!spend.evidence_ids?.length && <p className="text-flat-muted-fg">{spend.evidence_ids.length} supporting document reference{spend.evidence_ids.length === 1 ? '' : 's'}</p>}
      </div>
    </details>
  </li>
}

function CategoryBreakdown({ buckets }: { buckets: Bucket[] }) {
  const currencies = [...new Set(buckets.map((b) => b.currency))].sort()
  if (!currencies.length) return <EmptyState size="sm" title="No spending in this selection" />
  return <div className="grid gap-8 p-5 md:grid-cols-2">
    {currencies.map((currency) => {
      const rows = buckets.filter((b) => b.currency === currency).sort((a, b) => BigInt(a.net_minor) > BigInt(b.net_minor) ? -1 : BigInt(a.net_minor) < BigInt(b.net_minor) ? 1 : 0)
      const abs = (v: string) => BigInt(v) < 0n ? -BigInt(v) : BigInt(v)
      const max = rows.reduce((m, b) => abs(b.net_minor) > m ? abs(b.net_minor) : m, 1n)
      return <div key={currency}>
        <h3 className="mb-4 font-mono text-xs text-flat-subtle-fg">{currency}</h3>
        <ul className="space-y-4">{rows.map((b) => <li key={b.key}>
          <div className="mb-1.5 flex justify-between gap-3 text-sm"><span>{b.label}</span><span className="font-mono tabular-nums">{formatMoney(b.net_minor, currency)}</span></div>
          <div className="h-1.5 overflow-hidden rounded-full bg-flat-muted" aria-hidden="true"><div className="h-full rounded-full bg-flat-primary" style={{ width: `${Number(abs(b.net_minor) * 10000n / max) / 100}%` }} /></div>
        </li>)}</ul>
      </div>
    })}
  </div>
}

export function FinanceContent({ api, userId }: { api: FinanceAPI; userId: string }) {
  const [view, setView] = useState<{ filter: Filter; offset: number }>(() => ({ filter: monthWindow(), offset: 0 }))
  const [draft, setDraft] = useState<Filter>(() => monthWindow())
  const [category, setCategory] = useState('')
  const [tag, setTag] = useState('')
  const [formError, setFormError] = useState('')
  const [exporting, setExporting] = useState(false)
  const [exportError, setExportError] = useState('')
  const exportController = useRef<AbortController | null>(null)
  useEffect(() => () => exportController.current?.abort(), [])
  const scope = ['finance', userId]
  const directory = useQuery({ queryKey: [...scope, 'directory'], queryFn: ({ signal }) => api.directory(signal), gcTime: 0, retry })
  const spends = useQuery({ queryKey: [...scope, 'spends', view], queryFn: ({ signal }) => api.search(view.filter, view.offset, signal), gcTime: 0, retry })
  const overview = useQuery({
    queryKey: [...scope, 'overview', view.filter], gcTime: 0, retry,
    queryFn: async ({ signal }) => {
      const [totals, categories, months] = await Promise.all([
        api.analyze(view.filter, 'total', signal), api.analyze(view.filter, 'category', signal), api.analyze(view.filter, 'month', signal),
      ])
      return { totals, categories, months }
    },
  })
  const refresh = () => { void directory.refetch(); void spends.refetch(); void overview.refetch() }
  const apply = (event: FormEvent) => {
    event.preventDefault()
    if (draft.from && draft.to && draft.from > draft.to) { setFormError('Choose an end date on or after the start date.'); return }
    if (draft.currency && !/^[A-Z]{3}$/.test(draft.currency)) { setFormError('Enter a three-letter currency code, such as USD or INR.'); return }
    setFormError(''); setExportError('')
    setView({ offset: 0, filter: {
      ...draft, search: draft.search?.trim() || undefined, currency: draft.currency || undefined,
      category_id: category && category !== 'uncategorized' ? category : undefined,
      uncategorized: category === 'uncategorized' || undefined, tag_ids: tag ? [tag] : undefined,
    } })
  }
  const download = async () => {
    const controller = new AbortController()
    exportController.current = controller
    setExporting(true); setExportError('')
    try {
      const csv = await api.export(view.filter, controller.signal)
      if (controller.signal.aborted) return
      const url = URL.createObjectURL(new Blob([csv], { type: 'text/csv;charset=utf-8' }))
      const link = document.createElement('a')
      link.href = url; link.download = 'spends.csv'; link.click()
      setTimeout(() => URL.revokeObjectURL(url), 1000)
    } catch (error) {
      if (!controller.signal.aborted) setExportError(error instanceof Error ? error.message : 'Could not export spends.')
    } finally { if (!controller.signal.aborted) setExporting(false) }
  }

  const error = directory.error || spends.error || overview.error
  const loading = directory.isPending || spends.isPending || overview.isPending
  return <div className="space-y-7">
    <header className="flex flex-wrap items-start justify-between gap-4">
      <div>
        <p className="mb-2 font-mono text-xs uppercase tracking-widest text-flat-subtle-fg">Personal finance</p>
        <h1 className="text-[clamp(1.9rem,3.4vw,2.6rem)] font-normal leading-[1.08] tracking-[-0.03em]">Spending</h1>
        <p className="mt-2 text-base text-flat-muted-fg">Understand where your money goes, across your devices.</p>
      </div>
      <div className="flex gap-2">
        <Button iconLeft={<RefreshCw size={16} />} onClick={refresh} disabled={directory.isFetching || spends.isFetching || overview.isFetching}>Refresh</Button>
        <Button iconLeft={<Download size={16} />} onClick={() => { void download() }} loading={exporting} disabled={loading || !!error}>Export CSV</Button>
      </div>
    </header>

    <form onSubmit={apply} className={`${panel} grid gap-4 p-5 sm:grid-cols-2 lg:grid-cols-4`}>
      <FormField title="From"><Input type="date" value={draft.from || ''} onChange={(e) => setDraft({ ...draft, from: e.target.value || undefined })} /></FormField>
      <FormField title="To"><Input type="date" value={draft.to || ''} onChange={(e) => setDraft({ ...draft, to: e.target.value || undefined })} /></FormField>
      <FormField title="Search"><Input placeholder="Merchant, note, or account" maxLength={200} value={draft.search || ''} onChange={(e) => setDraft({ ...draft, search: e.target.value })} /></FormField>
      <FormField title="Currency"><Input placeholder="All currencies" maxLength={3} value={draft.currency || ''} onChange={(e) => setDraft({ ...draft, currency: e.target.value.toUpperCase().trim() })} /></FormField>
      <FormField title="Category"><select className={selectStyle} value={category} onChange={(e) => setCategory(e.target.value)}><option value="">All categories</option><option value="uncategorized">Uncategorized</option>{directory.data?.categories.map((d) => <option key={d.id} value={d.id}>{d.name}</option>)}</select></FormField>
      <FormField title="Tag"><select className={selectStyle} value={tag} onChange={(e) => setTag(e.target.value)}><option value="">All tags</option>{directory.data?.tags.map((d) => <option key={d.id} value={d.id}>{d.name}</option>)}</select></FormField>
      <FormField title="Type"><select className={selectStyle} value={draft.kind || ''} onChange={(e) => setDraft({ ...draft, kind: e.target.value as Filter['kind'] || undefined })}><option value="">All types</option><option value="expense">Expenses</option><option value="refund">Refunds</option><option value="transfer">Transfers</option></select></FormField>
      <div className="flex items-end"><Button type="submit" variant="primary" fullWidth>Apply filters</Button></div>
      {formError && <p role="alert" className="text-sm text-flat-danger sm:col-span-2 lg:col-span-4">{formError}</p>}
    </form>
    {exportError && <p role="alert" className="text-sm text-flat-danger">{exportError}</p>}
    {error ? <EmptyState icon={<AlertTriangle />} title="Couldn't load your finances" body={error.message} action={{ label: 'Retry', onClick: refresh }} />
      : loading ? <PageSkeleton />
      : directory.data && spends.data && overview.data && <>
        <section aria-label="Spending totals" className="space-y-3">
          <h2 className="text-lg font-medium">Net spending</h2>
          <p className="text-sm text-flat-muted-fg">Expenses less refunds in the selected period. Transfers are excluded; currencies are kept separate.{view.filter.category_id || view.filter.uncategorized ? ' Totals include only the selected category portions; records show the full purchase.' : ''}</p>
          {overview.data.totals.current.length ? <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
            {overview.data.totals.current.map((b) => <div key={b.currency} className={`${panel} p-5`}>
              <p className="font-mono text-xs text-flat-subtle-fg">{b.currency}</p>
              <p className="mt-2 break-words text-2xl tabular-nums">{formatMoney(b.net_minor, b.currency)}</p>
              <dl className="mt-4 space-y-2 text-sm text-flat-muted-fg">
                <div className="flex justify-between gap-3"><dt>Expenses</dt><dd>{formatMoney(b.expense_minor, b.currency)}</dd></div>
                <div className="flex justify-between gap-3"><dt>Refunds</dt><dd>{formatMoney(b.refund_minor, b.currency)}</dd></div>
              </dl>
            </div>)}
          </div> : <p className="text-sm text-flat-muted-fg">No expenses or refunds match these filters.</p>}
        </section>
        <section>
          <h2 className="mb-3 text-lg font-medium">By category</h2>
          <div className={panel}><CategoryBreakdown buckets={overview.data.categories.current} /></div>
        </section>
        {overview.data.months.current.length > 0 && <section>
          <h2 className="mb-3 text-lg font-medium">Monthly spending</h2>
          <div className={`${panel} overflow-x-auto`}><table className="w-full text-left text-sm">
            <caption className="sr-only">Net spending by month and currency within the selected dates</caption>
            <thead className="border-b border-flat-border text-flat-muted-fg"><tr><th scope="col" className="px-5 py-3">Month</th><th scope="col" className="px-5 py-3">Currency</th><th scope="col" className="px-5 py-3 text-right">Net spending</th></tr></thead>
            <tbody>{overview.data.months.current.map((b) => <tr key={`${b.currency}:${b.key}`} className="border-b border-flat-border last:border-0"><th scope="row" className="px-5 py-3 font-normal">{b.key.slice(0, 7)}</th><td className="px-5 py-3">{b.currency}</td><td className="px-5 py-3 text-right font-mono tabular-nums">{formatMoney(b.net_minor, b.currency)}</td></tr>)}</tbody>
          </table></div>
        </section>}
        <section>
          <div className="mb-3 flex items-baseline justify-between gap-3"><h2 className="text-lg font-medium">Spending records</h2><p className="text-sm text-flat-muted-fg">{spends.data.total} matching records</p></div>
          <div className={panel}>
            {spends.data.items.length ? <ul className="divide-y divide-flat-border">{spends.data.items.map((s) => <SpendRow key={s.id} spend={s} directory={directory.data} />)}</ul>
              : <EmptyState icon={<ReceiptText />} title="No matching spends" body="Try a wider date range or different filters. Spends recorded in your mobile app or by your agent appear here." />}
            <div className="flex items-center justify-between gap-3 border-t border-flat-border px-5 py-3">
              <Button size="sm" disabled={view.offset === 0} onClick={() => setView({ ...view, offset: Math.max(0, view.offset - 50) })}>Previous</Button>
              <span className="text-xs text-flat-muted-fg">{spends.data.items.length ? `${view.offset + 1}–${view.offset + spends.data.items.length} of ${spends.data.total}` : '0 shown'}</span>
              <Button size="sm" disabled={spends.data.next_offset === null} onClick={() => setView({ ...view, offset: spends.data.next_offset! })}>Next</Button>
            </div>
          </div>
        </section>
      </>}
  </div>
}

export default function Finance() {
  return <FinanceAuth>{(api, userId) => <FinanceContent key={userId} api={api} userId={userId} />}</FinanceAuth>
}
