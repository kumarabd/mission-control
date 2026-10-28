import { createElement } from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { describe, expect, it } from 'vitest'
import { FinanceContent } from '../pages/Finance'
import { createFinanceAPI } from './api'
import { monthWindow } from './format'

function fixture(owner: string) {
  const client = new QueryClient({ defaultOptions: { queries: { staleTime: Infinity, retry: false } } })
  const filter = monthWindow()
  const bucket = (currency: string, amount: string, key = 'total', label = 'Total') => ({ currency, key, label, count: 1, expense_minor: amount, refund_minor: '0', net_minor: amount })
  const analysis = (current: ReturnType<typeof bucket>[]) => ({ current, comparison: [], groups_overlap: false })
  const prefix = ['finance', owner]
  client.setQueryData([...prefix, 'directory'], {
    merchants: [{ id: 'm', name: 'Corner shop' }], categories: [{ id: 'c', name: 'Groceries' }], tags: [{ id: 't', name: 'Household' }],
  })
  client.setQueryData([...prefix, 'spends', { filter, offset: 0 }], { items: [{
    id: 's', version: 1, occurred_on: filter.to, kind: 'expense', amount_minor: 4500, currency: 'USD', merchant_id: 'm',
    description: 'Weekly shopping', allocations: [{ category_id: 'c', amount_minor: 4000 }, { amount_minor: 500 }], tag_ids: ['t'], evidence_ids: ['e'],
  }, { id: 'transfer', version: 1, occurred_on: filter.to, kind: 'transfer', amount_minor: 10000, currency: 'USD', description: 'Card payment' }], total: 2, next_offset: null })
  client.setQueryData([...prefix, 'overview', filter], {
    totals: analysis([bucket('USD', '4500'), bucket('INR', '120000')]),
    categories: analysis([bucket('USD', '4000', 'c', 'Groceries'), bucket('USD', '500', 'uncategorized', 'Uncategorized'), bucket('INR', '120000', 'c', 'Groceries')]),
    months: analysis([bucket('USD', '4500', filter.from), bucket('INR', '120000', filter.from)]),
  })
  return client
}
function render(client: QueryClient, owner: string) {
  return renderToStaticMarkup(createElement(QueryClientProvider, { client }, createElement(FinanceContent, { api: createFinanceAPI(async () => 'test'), userId: owner })))
}

describe('finance overview', () => {
  it('renders canonical spends, split categories, tags, transfers and separate currencies', () => {
    const client = fixture('a')
    const html = render(client, 'a')
    for (const text of ['Corner shop', 'Weekly shopping', 'Household', 'Uncategorized', 'USD', 'INR', 'Excluded from totals', '2 matching records', 'Export CSV']) expect(html).toContain(text)
    expect(html).not.toContain('Recent transactions')
    client.clear()
  })
  it('does not show another user’s cached records or totals', () => {
    const client = fixture('a')
    const html = render(client, 'b')
    expect(html).not.toContain('Corner shop')
    expect(html).not.toContain('Weekly shopping')
    client.clear()
  })
})

export { fixture, render }
