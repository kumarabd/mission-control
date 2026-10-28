import { afterEach, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest'

// gateway.ts reads window.__RUNTIME_CONFIG__ at module-load time (GATEWAY_BASE's top-level const), and
// request.ts's fetchWithTimeout reads window.setTimeout/clearTimeout on every call — this repo has no DOM test
// environment configured (no jsdom/happy-dom dependency, no vitest config) and no test file for this module
// existed before this one. Rather than add a new dependency or touch either module's existing code for a
// repo-wide environment change, stub just enough of `window` (real timers, not fakes) and import the module
// dynamically so the stub is in place before it evaluates — contained entirely to this test file.
const windowStub = { setTimeout: globalThis.setTimeout, clearTimeout: globalThis.clearTimeout }

let listPersonas: typeof import('./gateway').listPersonas
let createPersona: typeof import('./gateway').createPersona
let updatePersona: typeof import('./gateway').updatePersona

beforeAll(async () => {
  vi.stubGlobal('window', windowStub)
  ;({ listPersonas, createPersona, updatePersona } = await import('./gateway'))
})

beforeEach(() => vi.stubGlobal('window', windowStub))

const json = (value: unknown, status = 200) => new Response(JSON.stringify(value), { status })
const getToken = async () => 'test-token'

afterEach(() => vi.unstubAllGlobals())

describe('gateway persona (agent registry) client', () => {
  it('lists personas against GET /agents with a bearer token', async () => {
    const persona = {
      agent_id: 'main', display_name: 'Nighthawk', avatar_url: null, description: '',
      persona: 'You are helpful.', status: 'active', created_at: '2026-01-01T00:00:00Z',
    }
    const fetch = vi.fn().mockResolvedValue(json({ agents: [persona] }))
    vi.stubGlobal('fetch', fetch)

    const result = await listPersonas(getToken)

    expect(result).toEqual([persona])
    const [url, init] = fetch.mock.calls[0]
    expect(url).toBe('/gateway/agents')
    expect(init).toMatchObject({ headers: expect.objectContaining({ Authorization: 'Bearer test-token' }) })
  })

  it('treats a null agents list as empty, not a thrown error', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(json({ agents: null })))
    expect(await listPersonas(getToken)).toEqual([])
  })

  it('POSTs the real snake_case body shape to create a persona', async () => {
    const created = {
      agent_id: 'a1b2', display_name: 'Researcher', avatar_url: null, description: 'd',
      persona: 'p', status: 'active', created_at: '2026-01-02T00:00:00Z',
    }
    const fetch = vi.fn().mockResolvedValue(json(created))
    vi.stubGlobal('fetch', fetch)

    const result = await createPersona(getToken, { display_name: 'Researcher', persona: 'p', description: 'd' })

    expect(result).toEqual(created)
    const [url, init] = fetch.mock.calls[0]
    expect(url).toBe('/gateway/agents')
    expect(init).toMatchObject({
      method: 'POST',
      headers: expect.objectContaining({ 'Content-Type': 'application/json', Authorization: 'Bearer test-token' }),
      body: JSON.stringify({ display_name: 'Researcher', persona: 'p', description: 'd' }),
    })
  })

  it('PATCHes only the given fields to update a persona', async () => {
    const updated = {
      agent_id: 'a1b2', display_name: 'Researcher', avatar_url: null, description: 'd',
      persona: 'revised', status: 'active', created_at: '2026-01-02T00:00:00Z',
    }
    const fetch = vi.fn().mockResolvedValue(json(updated))
    vi.stubGlobal('fetch', fetch)

    const result = await updatePersona(getToken, 'a1b2', { persona: 'revised' })

    expect(result).toEqual(updated)
    const [url, init] = fetch.mock.calls[0]
    expect(url).toBe('/gateway/agents/a1b2')
    expect(init).toMatchObject({ method: 'PATCH', body: JSON.stringify({ persona: 'revised' }) })
  })

  it("surfaces the gateway's own plain-text error body (not a JSON envelope) as the error message", async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(new Response('the default agent cannot be disabled', { status: 400, statusText: 'Bad Request' })),
    )
    await expect(updatePersona(getToken, 'main', { status: 'disabled' })).rejects.toMatchObject({
      status: 400,
      message: 'the default agent cannot be disabled',
    })
  })

  it('never calls fetch when there is no token', async () => {
    const fetch = vi.fn()
    vi.stubGlobal('fetch', fetch)
    await expect(listPersonas(async () => null)).rejects.toMatchObject({ status: 401 })
    expect(fetch).not.toHaveBeenCalled()
  })
})
