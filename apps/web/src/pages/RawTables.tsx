import { useSearchParams } from 'react-router-dom'
import { useQuery, keepPreviousData } from '@tanstack/react-query'
import Button from '../components/ui/Button'
import EmptyState from '../components/ui/EmptyState'
import PageHeader from '../components/ui/PageHeader'
import Select from '../components/ui/Select'
import { getRawTableRows, getRawTables } from '../lib/api'
import { formatDateTime } from '../lib/format'
import type { RawTableGroup, RawTableInfo } from '../lib/types'

const PAGE_SIZE = 50

const GROUP_LABELS: Record<RawTableGroup, string> = {
  episodic: 'Episodic',
  semantic: 'Semantic',
  meta: 'Meta',
}

const GROUP_ORDER: RawTableGroup[] = ['episodic', 'semantic', 'meta']

// Columns that are always ISO timestamps by name — formatted as dates rather than raw
// strings. jsonb/uuid/etc. columns are self-evident from their content and don't need a
// naming heuristic.
function isTimestampColumn(name: string): boolean {
  return name === 'created_at' || name === 'updated_at' || name.endsWith('_at') || name.endsWith('_time')
}

function formatCell(column: string, value: unknown): { text: string; title?: string } {
  if (value === null || value === undefined) {
    return { text: '—' }
  }
  if (typeof value === 'boolean') {
    return { text: value ? 'true' : 'false' }
  }
  if (typeof value === 'number') {
    return { text: String(value) }
  }
  if (typeof value === 'string') {
    if (isTimestampColumn(column) && !Number.isNaN(Date.parse(value))) {
      return { text: formatDateTime(value), title: value }
    }
    return { text: value }
  }
  // jsonb columns (objects/arrays) decode as-is from the API.
  const json = JSON.stringify(value)
  return { text: json, title: json }
}

function TableSwitcher({
  tables,
  group,
  table,
  onGroupChange,
  onTableChange,
}: {
  tables: RawTableInfo[]
  group: RawTableGroup | 'all'
  table: string
  onGroupChange: (group: RawTableGroup | 'all') => void
  onTableChange: (table: string) => void
}) {
  const groupOptions = [
    { value: 'all', label: 'All groups' },
    ...GROUP_ORDER.map((g) => ({ value: g, label: GROUP_LABELS[g] })),
  ]
  const visibleTables = group === 'all' ? tables : tables.filter((t) => t.group === group)
  const tableOptions = visibleTables.map((t) => ({ value: t.name, label: t.label }))

  return (
    <div className="flex flex-wrap items-center gap-3">
      <label className="flex items-center gap-2 text-xs text-flat-muted-fg">
        Group
        <Select
          className="min-w-[10rem]"
          options={groupOptions}
          value={group}
          onChange={(e) => onGroupChange(e.target.value as RawTableGroup | 'all')}
        />
      </label>
      <label className="flex items-center gap-2 text-xs text-flat-muted-fg">
        Table
        <Select
          className="min-w-[14rem]"
          options={tableOptions}
          value={table}
          placeholder="Choose a table…"
          onChange={(e) => onTableChange(e.target.value)}
        />
      </label>
    </div>
  )
}

export default function RawTables() {
  const [searchParams, setSearchParams] = useSearchParams()
  const groupParam = (searchParams.get('group') as RawTableGroup | 'all' | null) ?? 'all'
  const offset = Math.max(0, Number(searchParams.get('offset') ?? 0) || 0)

  const tables = useQuery({ queryKey: ['raw-tables'], queryFn: getRawTables })
  const allTables = tables.data?.items ?? []

  const table = searchParams.get('table') || allTables[0]?.name || ''

  const rows = useQuery({
    queryKey: ['raw-table-rows', table, offset],
    queryFn: () => getRawTableRows(table, { limit: PAGE_SIZE, offset }),
    enabled: table !== '',
    placeholderData: keepPreviousData,
  })

  const activeTableInfo = allTables.find((t) => t.name === table) ?? null

  function updateParams(next: Record<string, string | null>) {
    const params = new URLSearchParams(searchParams)
    for (const [key, value] of Object.entries(next)) {
      if (value === null || value === '') params.delete(key)
      else params.set(key, value)
    }
    setSearchParams(params, { replace: true })
  }

  function selectGroup(group: RawTableGroup | 'all') {
    const stillVisible =
      group === 'all' || allTables.find((t) => t.name === table)?.group === group
    updateParams({ group: group === 'all' ? null : group, offset: null, ...(stillVisible ? {} : { table: null }) })
  }

  function selectTable(nextTable: string) {
    updateParams({ table: nextTable, offset: null })
  }

  function goPrev() {
    updateParams({ offset: String(Math.max(0, offset - PAGE_SIZE)) })
  }

  function goNext() {
    updateParams({ offset: String(offset + PAGE_SIZE) })
  }

  const items = rows.data?.items ?? []
  const columns = rows.data?.columns ?? []
  const hasNextPage = items.length === PAGE_SIZE

  return (
    <div className="space-y-6">
      <PageHeader
        title="Raw tables"
        description="Every table exactly as stored, for when you want to look underneath. Pick a table and page through its rows."
      />

      {tables.isError && (
        <p className="text-sm text-flat-danger">Couldn't load the table list. {String(tables.error)}</p>
      )}

      {!tables.isError && (
        <TableSwitcher
          tables={allTables}
          group={groupParam}
          table={table}
          onGroupChange={selectGroup}
          onTableChange={selectTable}
        />
      )}

      {activeTableInfo && (
        <p className="text-xs text-flat-muted-fg">
          <span className="rounded-full bg-flat-tint px-2 py-0.5 font-mono uppercase tracking-wide">
            {GROUP_LABELS[activeTableInfo.group]}
          </span>{' '}
          <span className="font-mono">{activeTableInfo.name}</span>
        </p>
      )}

      {rows.isError && (
        <p className="text-sm text-flat-danger">Couldn't load rows. {String(rows.error)}</p>
      )}

      {!rows.isError && rows.isLoading && <p className="text-sm text-flat-muted-fg">Loading rows…</p>}

      {!rows.isError && !rows.isLoading && table && items.length === 0 && (
        <EmptyState>No rows in {table} yet.</EmptyState>
      )}

      {items.length > 0 && (
        <div className="overflow-x-auto rounded-2xl border border-flat-border bg-flat-surface">
          <table className="w-full border-collapse text-left">
            <thead>
              <tr>
                {columns.map((col) => (
                  <th key={col} className="whitespace-nowrap border-b border-flat-border bg-flat-tint-soft px-4 py-2.5 font-mono text-xs font-medium text-flat-subtle-fg">
                    {col}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {items.map((row, i) => (
                // Raw rows have no single reliable primary-key column across every table
                // (some are composite-keyed edge tables) — row position within the page is
                // stable enough as a React key since a page's contents don't reorder in place.
                <tr key={i} className="transition-colors hover:bg-flat-tint-soft">
                  {columns.map((col) => {
                    const { text, title } = formatCell(col, row[col])
                    return (
                      <td key={col} title={title} className="max-w-xs truncate border-b border-flat-border px-4 py-2.5 font-mono text-xs text-flat-foreground">
                        {text}
                      </td>
                    )
                  })}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {items.length > 0 && (
        <div className="flex items-center justify-between">
          <p className="text-xs text-flat-muted-fg">
            Showing {offset + 1}–{offset + items.length}
          </p>
          <div className="flex gap-2">
            <Button variant="outline" disabled={offset === 0} onClick={goPrev}>
              Previous
            </Button>
            <Button variant="outline" disabled={!hasNextPage} onClick={goNext}>
              Next
            </Button>
          </div>
        </div>
      )}
    </div>
  )
}
