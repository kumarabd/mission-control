import type { ReactNode } from 'react'
import { ArrowDown, ArrowUp, Search } from 'lucide-react'
import { cn } from '../../lib/cn'
import { Button, EmptyState, SkeletonRows } from '../ui'

export type SortState = { columnId: string; dir: 'asc' | 'desc' }

export type Column<Row> = {
  id: string
  header: ReactNode
  cell: (row: Row) => ReactNode
  sortable?: boolean
  align?: 'left' | 'right'
  width?: string
  mono?: boolean
  hideBelow?: 'sm' | 'md' | 'lg'
}

const hideClass: Record<string, string> = {
  sm: 'hidden sm:table-cell',
  md: 'hidden md:table-cell',
  lg: 'hidden lg:table-cell',
}

export type DataListProps<Row> = {
  columns: Column<Row>[]
  rows: Row[]
  rowKey: (row: Row) => string
  isLoading?: boolean
  error?: unknown
  onRetry?: () => void
  sort?: SortState
  onSortChange?: (s: SortState) => void
  onRowClick?: (row: Row) => void
  selectedRowKey?: string
  pagination?: {
    offset: number
    limit: number
    hasMore?: boolean
    total?: number
    onChange: (offset: number) => void
  }
  toolbar?: ReactNode
  emptyState: ReactNode
  density?: 'comfortable' | 'compact'
}

export function DataList<Row>({
  columns,
  rows,
  rowKey,
  isLoading,
  error,
  onRetry,
  sort,
  onSortChange,
  onRowClick,
  selectedRowKey,
  pagination,
  toolbar,
  emptyState,
  density = 'comfortable',
}: DataListProps<Row>) {
  const pad = density === 'compact' ? 'px-3 py-1.5' : 'px-3 py-2.5'

  const toggleSort = (id: string) => {
    if (!onSortChange) return
    const dir = sort?.columnId === id && sort.dir === 'asc' ? 'desc' : 'asc'
    onSortChange({ columnId: id, dir })
  }

  return (
    <div className="flex flex-col gap-3">
      {toolbar}

      <div className="overflow-hidden rounded-md border border-flat-border bg-flat-surface">
        <div className="overflow-x-auto">
          <table className="w-full text-base">
            <thead>
              <tr className="border-b border-flat-border">
                {columns.map((col) => (
                  <th
                    key={col.id}
                    style={{ width: col.width }}
                    className={cn(
                      'px-3 py-2 text-2xs font-medium text-flat-subtle-fg',
                      col.align === 'right' ? 'text-right' : 'text-left',
                      col.hideBelow && hideClass[col.hideBelow],
                    )}
                  >
                    {col.sortable && onSortChange ? (
                      <button
                        type="button"
                        onClick={() => toggleSort(col.id)}
                        className="inline-flex items-center gap-1 hover:text-flat-muted-fg"
                      >
                        {col.header}
                        {sort?.columnId === col.id &&
                          (sort.dir === 'asc' ? <ArrowUp className="size-3" /> : <ArrowDown className="size-3" />)}
                      </button>
                    ) : (
                      col.header
                    )}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {isLoading ? (
                <tr>
                  <td colSpan={columns.length} className="p-3">
                    <SkeletonRows count={8} />
                  </td>
                </tr>
              ) : error ? (
                <tr>
                  <td colSpan={columns.length}>
                    <EmptyState
                      size="sm"
                      title="Couldn't load this list"
                      body={onRetry ? undefined : 'Try refreshing the page.'}
                      action={onRetry ? { label: 'Retry', onClick: onRetry } : undefined}
                    />
                  </td>
                </tr>
              ) : rows.length === 0 ? (
                <tr>
                  <td colSpan={columns.length}>{emptyState}</td>
                </tr>
              ) : (
                rows.map((row) => {
                  const key = rowKey(row)
                  return (
                    <tr
                      key={key}
                      onClick={onRowClick ? () => onRowClick(row) : undefined}
                      className={cn(
                        'border-b border-flat-border last:border-0',
                        onRowClick && 'cursor-pointer hover:bg-flat-muted',
                        selectedRowKey === key && 'bg-flat-tint',
                      )}
                    >
                      {columns.map((col) => (
                        <td
                          key={col.id}
                          className={cn(
                            pad,
                            'align-middle',
                            col.align === 'right' ? 'text-right' : 'text-left',
                            col.mono && 'font-mono text-sm',
                            col.hideBelow && hideClass[col.hideBelow],
                          )}
                        >
                          {col.cell(row)}
                        </td>
                      ))}
                    </tr>
                  )
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {pagination && rows.length > 0 && (
        <div className="flex items-center justify-between text-sm text-flat-muted-fg">
          <span>
            {pagination.offset + 1}–{pagination.offset + rows.length}
            {pagination.total != null && ` of ${pagination.total}`}
          </span>
          <div className="flex gap-2">
            <Button
              size="sm"
              variant="ghost"
              disabled={pagination.offset === 0}
              onClick={() => pagination.onChange(Math.max(0, pagination.offset - pagination.limit))}
            >
              Previous
            </Button>
            <Button
              size="sm"
              variant="ghost"
              disabled={pagination.hasMore === false || rows.length < pagination.limit}
              onClick={() => pagination.onChange(pagination.offset + pagination.limit)}
            >
              Next
            </Button>
          </div>
        </div>
      )}
    </div>
  )
}

export function FilterBar({
  search,
  filters,
  right,
}: {
  search?: { value: string; onChange: (v: string) => void; placeholder?: string }
  filters?: ReactNode
  right?: ReactNode
}) {
  return (
    <div className="flex flex-wrap items-center gap-2">
      {search && (
        <label className="flex h-9 min-w-56 max-w-sm flex-1 items-center gap-2 rounded-full border border-flat-border bg-flat-surface px-3.5 transition-colors focus-within:border-flat-primary">
          <Search className="size-4 shrink-0 text-flat-subtle-fg" aria-hidden />
          <input
            value={search.value}
            onChange={(e) => search.onChange(e.target.value)}
            placeholder={search.placeholder ?? 'Search…'}
            aria-label={search.placeholder ?? 'Search'}
            className="min-w-0 flex-1 bg-transparent text-sm text-flat-foreground outline-none placeholder:text-flat-subtle-fg"
          />
        </label>
      )}
      {filters}
      {right && <div className="ml-auto">{right}</div>}
    </div>
  )
}
