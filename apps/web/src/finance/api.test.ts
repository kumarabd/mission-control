import { afterEach, describe, expect, it, vi } from 'vitest'
import { createFinanceAPI, financeBase } from './api'

const json = (value: unknown, status = 200) => new Response(JSON.stringify(value), { status })
afterEach(() => vi.unstubAllGlobals())

describe('finance router contract', () => {
  it('uses the router finance prefix for runtime, build-time, gateway and same-origin configurations', () => {
    expect(financeBase('https://router.example/', 'https://other.example')).toBe('https://router.example/finance/api/v1')
    expect(financeBase('', 'https://router.example/')).toBe('https://router.example/finance/api/v1')
    expect(financeBase('', '', 'https://router.example/gateway/')).toBe('https://router.example/finance/api/v1')
    expect(financeBase()).toBe('/finance/api/v1')
  })

  it('POSTs operation arguments through the router using only a bearer token for identity', async () => {
    const fetch = vi.fn().mockImplementation(async () => json({ items: [], total: 0, next_offset: null }))
    vi.stubGlobal('fetch', fetch)
    const api = createFinanceAPI(async () => 'session-token', 'https://router.example/finance/api/v1')
    const filter = { from: '2026-10-01', to: '2026-10-31', category_id: 'category', tag_ids: ['tag'] }
    await api.search(filter, 50)
    expect(fetch).toHaveBeenCalledWith('https://router.example/finance/api/v1/operations/spends_search', expect.objectContaining({
      method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: 'Bearer session-token' },
      body: JSON.stringify({ ...filter, offset: 50, limit: 50 }), cache: 'no-store',
    }))
  })

  it('refreshes a rejected token once and retains the exact request body', async () => {
    const fetch = vi.fn().mockResolvedValueOnce(json({ error: 'invalid session token' }, 401)).mockResolvedValueOnce(json({ current: [], comparison: [] }))
    vi.stubGlobal('fetch', fetch)
    const token = vi.fn().mockResolvedValueOnce('old').mockResolvedValueOnce('fresh')
    await createFinanceAPI(token, '/finance/api/v1').analyze({}, 'category')
    expect(token.mock.calls).toEqual([[false], [true]])
    expect(fetch.mock.calls[1][1].headers.Authorization).toBe('Bearer fresh')
    expect(fetch.mock.calls[1][1].body).toBe(fetch.mock.calls[0][1].body)
  })

  it('does not send anonymous finance requests', async () => {
    const fetch = vi.fn(); vi.stubGlobal('fetch', fetch)
    await expect(createFinanceAPI(async () => null).search({})).rejects.toMatchObject({ status: 401 })
    expect(fetch).not.toHaveBeenCalled()
  })

  it('handles router provisioning errors and engine errors', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValueOnce(json({ error: 'no_tenant' }, 404)).mockResolvedValueOnce(json({ error: { code: 'invalid_input', message: 'Invalid dates' } }, 400)))
    const api = createFinanceAPI(async () => 'token')
    await expect(api.search({})).rejects.toMatchObject({ status: 404, code: 'no_tenant', message: 'Your finance service is not set up yet.' })
    await expect(api.search({})).rejects.toMatchObject({ status: 400, code: 'invalid_input', message: 'Invalid dates' })
  })

  it('loads every directory page, not just the first 200 labels', async () => {
    const fetch = vi.fn(async (url: string, init: RequestInit) => {
      const { offset } = JSON.parse(init.body as string)
      return url.includes('categories_list') && offset === 0
        ? json({ items: [{ id: 'a', name: 'First' }], total: 2, next_offset: 200 })
        : url.includes('categories_list')
          ? json({ items: [{ id: 'b', name: 'Later' }], total: 2, next_offset: null })
          : json({ items: [], total: 0, next_offset: null })
    })
    vi.stubGlobal('fetch', fetch)
    const result = await createFinanceAPI(async () => 'token').directory()
    expect(result.categories.map((d) => d.id)).toEqual(['a', 'b'])
  })

  it('exports all filtered pages and retains exactly one CSV header', async () => {
    const fetch = vi.fn().mockResolvedValueOnce(json({ csv: 'id,note\na,"two\nlines"\n', total: 2, next_offset: 1 })).mockResolvedValueOnce(json({ csv: 'id,note\nb,second\n', total: 2, next_offset: null }))
    vi.stubGlobal('fetch', fetch)
    const csv = await createFinanceAPI(async () => 'token').export({ currency: 'INR' })
    expect(csv).toBe('id,note\na,"two\nlines"\nb,second\n')
    expect(JSON.parse(fetch.mock.calls[1][1].body)).toEqual({ currency: 'INR', offset: 1, limit: 200 })
  })

  it('keeps session token getters separate and forwards cancellation', async () => {
    const fetch = vi.fn().mockImplementation(async () => json({ items: [], total: 0, next_offset: null }))
    vi.stubGlobal('fetch', fetch)
    const a = createFinanceAPI(async () => 'user-a'), b = createFinanceAPI(async () => 'user-b')
    const controller = new AbortController()
    await a.search({}, 0, controller.signal); await b.search({})
    expect(fetch.mock.calls[0][1].headers.Authorization).toBe('Bearer user-a')
    expect(fetch.mock.calls[1][1].headers.Authorization).toBe('Bearer user-b')
    expect(fetch.mock.calls[0][1].signal).toBe(controller.signal)
  })
})
