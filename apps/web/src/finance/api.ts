export type Spend = {
  id: string
  version: number
  occurred_on: string
  kind: 'expense' | 'refund' | 'transfer'
  amount_minor: number
  currency: string
  merchant_id?: string
  description?: string
  account_ref?: string
  original_spend_id?: string
  allocations?: { category_id?: string; amount_minor: number }[]
  tag_ids?: string[]
  evidence_ids?: string[]
}
export type Dimension = { id: string; name: string; aliases?: string[] }
export type Page<T> = { items: T[]; total: number; next_offset: number | null }
export type Filter = {
  from?: string; to?: string; search?: string; currency?: string
  kind?: Spend['kind']; category_id?: string; uncategorized?: boolean; tag_ids?: string[]
}
export type Bucket = {
  currency: string; key: string; label: string; count: number
  expense_minor: string; refund_minor: string; net_minor: string
}
export type Analysis = { current: Bucket[]; comparison: Bucket[]; group_by: string; groups_overlap: boolean }
export type Directory = { categories: Dimension[]; merchants: Dimension[]; tags: Dimension[] }
export type ExportPage = { csv: string; total: number; next_offset: number | null }
export type TokenGetter = (skipCache: boolean) => Promise<string | null>

export class FinanceError extends Error {
  status: number
  code?: string
  constructor(status: number, message: string, code?: string) {
    super(message)
    this.name = 'FinanceError'; this.status = status; this.code = code
  }
}

/** Always append the router's finance prefix. No direct engine URL or verified-user headers. */
export function financeBase(runtime = '', configured = '', gateway = '') {
  const clean = (s: string) => s.trim().replace(/\/+$/, '')
  const router = clean(runtime) || clean(configured) || clean(gateway).replace(/\/gateway$/, '')
  return `${router}/finance/api/v1`
}
export function defaultFinanceBase() {
  return financeBase(
    typeof window === 'undefined' ? '' : window.__RUNTIME_CONFIG__?.ROUTER_BASE_URL,
    import.meta.env.VITE_ROUTER_BASE_URL,
    import.meta.env.VITE_GATEWAY_BASE_URL,
  )
}

export function createFinanceAPI(getToken: TokenGetter, base = defaultFinanceBase()) {
  async function call<T>(operation: string, input: object, signal?: AbortSignal): Promise<T> {
    const send = async (skipCache: boolean) => {
      const token = await getToken(skipCache)
      if (!token) throw new FinanceError(401, 'Sign in again to load your finances.')
      return fetch(`${base}/operations/${operation}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify(input), signal, cache: 'no-store',
      })
    }
    let response = await send(false)
    if (response.status === 401) response = await send(true)
    if (!response.ok) {
      let message = `Finance request failed (${response.status}).`
      let code: string | undefined
      try {
        const body = await response.json()
        if (typeof body?.error === 'string') code = body.error
        else { code = body?.error?.code; message = body?.error?.message || message }
      } catch { /* A router failure can have a non-JSON response. */ }
      if (code === 'no_tenant') message = 'Your finance service is not set up yet.'
      else if (response.status === 401) message = 'Your session expired. Sign in again.'
      else if (response.status === 403) message = 'Finance access was denied. Check the router and allowed web origin.'
      throw new FinanceError(response.status, message, code)
    }
    try { return await response.json() as T }
    catch { throw new FinanceError(502, 'The finance service returned an unreadable response.') }
  }
  async function dimensions(kind: 'categories' | 'merchants' | 'tags', signal?: AbortSignal) {
    const items: Dimension[] = []
    let offset = 0
    while (true) {
      const page = await call<Page<Dimension>>(`${kind}_list`, { limit: 200, offset }, signal)
      items.push(...page.items)
      if (page.next_offset === null) return items
      if (page.next_offset <= offset) throw new FinanceError(502, 'The finance service returned invalid pagination.')
      offset = page.next_offset
    }
  }
  return {
    search: (filter: Filter, offset = 0, signal?: AbortSignal) => call<Page<Spend>>('spends_search', { ...filter, offset, limit: 50 }, signal),
    analyze: (filter: Filter, group_by: 'total' | 'category' | 'month', signal?: AbortSignal) => call<Analysis>('spending_analyze', { ...filter, group_by }, signal),
    directory: async (signal?: AbortSignal): Promise<Directory> => {
      const [categories, merchants, tags] = await Promise.all([
        dimensions('categories', signal), dimensions('merchants', signal), dimensions('tags', signal),
      ])
      return { categories, merchants, tags }
    },
    export: async (filter: Filter, signal?: AbortSignal) => {
      const pages: string[] = []
      let offset = 0
      while (true) {
        const page = await call<ExportPage>('spends_export', { ...filter, offset, limit: 200 }, signal)
        pages.push(offset === 0 ? page.csv : page.csv.slice(page.csv.indexOf('\n') + 1))
        if (page.next_offset === null) return pages.join('')
        if (page.next_offset <= offset) throw new FinanceError(502, 'The finance service returned invalid pagination.')
        offset = page.next_offset
      }
    },
  }
}
export type FinanceAPI = ReturnType<typeof createFinanceAPI>
