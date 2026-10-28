import { afterEach, beforeAll, describe, expect, it, vi } from 'vitest'
const windowStub = {
  setTimeout: globalThis.setTimeout,
  clearTimeout: globalThis.clearTimeout,
  location: { search: '' },
}

let lifeRequest: typeof import('./client').lifeRequest
let providerRequest: typeof import('./client').providerRequest
let LifeError: typeof import('./client').LifeError

beforeAll(async () => {
  vi.stubGlobal('window', windowStub)
  vi.stubGlobal('localStorage', {
    getItem: (key: string) => (key === 'explorer.token' ? 'test-token' : null),
    setItem: () => {},
    removeItem: () => {},
  })
  ;({ lifeRequest, providerRequest, LifeError } = await import('./client'))
})

afterEach(() => {
  vi.unstubAllGlobals()
  vi.stubGlobal('window', windowStub)
  vi.stubGlobal('localStorage', {
    getItem: (key: string) => (key === 'explorer.token' ? 'test-token' : null),
    setItem: () => {},
    removeItem: () => {},
  })
})

const json = (value: unknown, status = 200) =>
  new Response(JSON.stringify(value), { status })

async function expectKind(
  response: Response,
  kind: string,
): Promise<void> {
  vi.stubGlobal('fetch', vi.fn().mockResolvedValue(response))
  await expect(lifeRequest('plan_get', {})).rejects.toMatchObject({ kind })
}

describe('Life client', () => {
  it('sends the operation, bearer token and JSON body', async () => {
    const fetch = vi.fn().mockResolvedValue(json({ day: '2026-01-01', items: [] }))
    vi.stubGlobal('fetch', fetch)

    await lifeRequest('plan_get', { day: '2026-01-01' })

    const [url, init] = fetch.mock.calls[0]
    expect(String(url)).toContain('/life/api/v1/operations/plan_get')
    expect(init.method).toBe('POST')
    expect(init.headers).toMatchObject({
      Authorization: 'Bearer test-token',
      'Content-Type': 'application/json',
    })
    expect(JSON.parse(init.body)).toEqual({ day: '2026-01-01' })
  })

  it('maps no_tenant to not_provisioned without treating it as an error page', async () => {
    await expectKind(
      json({ error: { code: 'no_tenant', message: 'no tenant' } }, 404),
      'not_provisioned',
    )
  })

  it('maps a stale version to conflict', async () => {
    await expectKind(
      json({ error: { code: 'conflict', message: 'version changed' } }, 409),
      'conflict',
    )
  })

  it('maps a busy or rate-limited engine to retry', async () => {
    await expectKind(json({ error: { code: 'busy' } }, 503), 'retry')
    await expectKind(json({ error: { code: 'rate_limited' } }, 429), 'retry')
  })

  it('maps invalid input and auth failures', async () => {
    await expectKind(json({ error: { code: 'invalid_input' } }, 400), 'invalid_input')
    await expectKind(json({ error: { code: 'unauthorized' } }, 401), 'unauthorized')
  })

  it('throws a LifeError carrying the operation and code', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(json({ error: { code: 'not_found' } }, 404)))
    const error = await lifeRequest('reminders_get', {}).catch((cause) => cause)
    expect(error).toBeInstanceOf(LifeError)
    expect(error).toMatchObject({ kind: 'not_found', operation: 'reminders_get', code: 'not_found' })
  })
})

describe('provider client', () => {
  it('posts to the provider\'s own router prefix with the bearer token', async () => {
    const fetch = vi.fn().mockResolvedValue(json({ provider: 'finance', series: 'spend_total_usd', unit: 'USD', granularity: 'day', points: [] }))
    vi.stubGlobal('fetch', fetch)

    await providerRequest('finance', 'series_get', { series: 'spend_total_usd' })

    const [url, init] = fetch.mock.calls[0]
    expect(String(url)).toBe('/finance/api/v1/operations/series_get')
    expect(init.headers).toMatchObject({ Authorization: 'Bearer test-token' })
    expect(JSON.parse(init.body)).toEqual({ series: 'spend_total_usd' })
  })

  it('refuses a provider id that could change the path, without calling out', async () => {
    const fetch = vi.fn()
    vi.stubGlobal('fetch', fetch)
    for (const bad of ['../life', 'finance/../life', 'Finance', 'a b', '', 'x'.repeat(65), '1finance']) {
      await expect(providerRequest(bad, 'series_get', {})).rejects.toMatchObject({ kind: 'invalid_input' })
    }
    expect(fetch).not.toHaveBeenCalled()
  })

  it('reports a series that is gone as not_found, and an unreachable provider as retry', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(json({ error: { code: 'not_found', message: 'That series does not exist' } }, 404)))
    await expect(providerRequest('finance', 'series_get', {})).rejects.toMatchObject({ kind: 'not_found' })
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(json({ error: { code: 'busy' } }, 503)))
    await expect(providerRequest('finance', 'series_get', {})).rejects.toMatchObject({ kind: 'retry' })
  })
})

