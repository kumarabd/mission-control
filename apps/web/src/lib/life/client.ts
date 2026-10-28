import { getRouterAuthHeaders } from '../api'
import { fetchWithTimeout } from '../request'
import { fixtureEnabled } from '../devFixture'
import type { LifeErrorEnvelope, LifeErrorKind } from './wire'

const runtimeRouter =
  typeof window !== 'undefined' ? (window.__RUNTIME_CONFIG__?.ROUTER_BASE_URL || '').trim().replace(/\/$/, '') : ''

/** Router-prefixed base; same-origin `/life` in production, router target in dev. */
export const LIFE_BASE = (
  import.meta.env.VITE_LIFE_BASE_URL ||
  (runtimeRouter ? `${runtimeRouter}/life/api/v1` : '/life/api/v1')
).replace(/\/$/, '')

export class LifeError extends Error {
  kind: LifeErrorKind
  status: number
  code: string
  operation: string

  constructor(message: string, kind: LifeErrorKind, status: number, code: string, operation: string) {
    super(message)
    this.name = 'LifeError'
    this.kind = kind
    this.status = status
    this.code = code
    this.operation = operation
  }
}

export function isLifeError(value: unknown): value is LifeError {
  return value instanceof LifeError
}

export function newIdempotencyKey(): string {
  if (typeof crypto !== 'undefined' && 'randomUUID' in crypto) return crypto.randomUUID()
  return `life-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`
}

function envelopeMessage(body: LifeErrorEnvelope | null): { code: string; message: string } {
  if (!body) return { code: '', message: '' }
  if (typeof body.error === 'string') return { code: body.error, message: body.error }
  if (body.error && typeof body.error === 'object') {
    return { code: body.error.code ?? '', message: body.error.message ?? body.error.code ?? '' }
  }
  return { code: '', message: body.message ?? '' }
}

function classify(status: number, code: string): LifeErrorKind {
  if (status === 401 || status === 403) return 'unauthorized'
  if (status === 404 && code === 'no_tenant') return 'not_provisioned'
  if (status === 404) return 'not_found'
  if (status === 409 || code === 'conflict') return 'conflict'
  if ([408, 429, 502, 503, 504].includes(status) || code === 'busy' || status === 503) return 'retry'
  if (code === 'invalid_input' || code === 'duplicate' || code === 'too_large') return code
  if (code) return 'engine'
  if (status >= 500) return 'server'
  return 'engine'
}

/** POST one Life Engine operation. Reads/writes share the same envelope. */
export async function lifeRequest<T>(
  operation: string,
  input: Record<string, unknown> = {},
  options: { signal?: AbortSignal; timeoutMs?: number } = {},
): Promise<T> {
  if (import.meta.env.DEV && fixtureEnabled()) {
    const { fixtureLifeResponse } = await import('./devFixtures')
    return fixtureLifeResponse(operation, input) as T
  }
  return post<T>(`${LIFE_BASE}/operations/${operation}`, operation, input, options)
}

const PROVIDER_ID = /^[a-z][a-z0-9_]{0,63}$/

/** The router's origin, the same one the finance pages use; empty means same-origin. */
function routerBase(): string {
  const clean = (value: string) => value.trim().replace(/\/+$/, '')
  return (
    runtimeRouter ||
    clean(import.meta.env.VITE_ROUTER_BASE_URL ?? '') ||
    clean(import.meta.env.VITE_GATEWAY_BASE_URL ?? '').replace(/\/gateway$/, '')
  )
}

/**
 * POST one operation to a data provider through the router: `<router>/<provider>/api/v1/operations/<operation>`.
 * A provider id comes from a stored view, so it is checked before it becomes part of a URL.
 */
export async function providerRequest<T>(
  provider: string,
  operation: string,
  input: Record<string, unknown> = {},
  options: { signal?: AbortSignal; timeoutMs?: number } = {},
): Promise<T> {
  if (!PROVIDER_ID.test(provider)) {
    throw new LifeError('This tracker names a data source this app cannot reach.', 'invalid_input', 0, 'invalid_provider', operation)
  }
  if (import.meta.env.DEV && fixtureEnabled()) {
    const { fixtureProviderResponse } = await import('./devFixtures')
    return fixtureProviderResponse(provider, operation, input) as T
  }
  return post<T>(`${routerBase()}/${provider}/api/v1/operations/${operation}`, operation, input, options)
}

async function post<T>(
  url: string,
  operation: string,
  input: Record<string, unknown>,
  options: { signal?: AbortSignal; timeoutMs?: number },
): Promise<T> {
  let response: Response
  try {
    response = await fetchWithTimeout(
      url,
      {
        method: 'POST',
        headers: {
          ...(await getRouterAuthHeaders()),
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(input ?? {}),
        signal: options.signal,
      },
      options.timeoutMs ?? 30_000,
    )
  } catch (error) {
    if (error instanceof Error && error.name === 'RequestTimeoutError') {
      throw new LifeError(error.message, 'retry', 0, 'timeout', operation)
    }
    throw new LifeError(
      error instanceof Error ? error.message : 'Could not reach your workspace.',
      'retry',
      0,
      'network',
      operation,
    )
  }

  const text = await response.text()
  let body: unknown = null
  if (text) {
    try {
      body = JSON.parse(text)
    } catch {
      body = null
    }
  }

  if (!response.ok) {
    const parsed = envelopeMessage((body as LifeErrorEnvelope | null) ?? null)
    const kind = classify(response.status, parsed.code)
    const fallback =
      kind === 'unauthorized'
        ? 'Please sign in again.'
        : kind === 'not_provisioned'
          ? 'Connect your workspace to use this feature.'
          : kind === 'conflict'
            ? 'That changed elsewhere. It has been refreshed.'
            : kind === 'retry'
              ? 'Your workspace is busy. Try again in a moment.'
              : parsed.message || response.statusText || 'Something went wrong.'
    throw new LifeError(parsed.message || fallback, kind, response.status, parsed.code, operation)
  }

  if (body == null) {
    throw new LifeError('Your workspace returned an unreadable response.', 'invalid_response', response.status, '', operation)
  }
  return body as T
}
