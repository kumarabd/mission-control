// Client for self-serve tenant onboarding (agent-harness's
// workflows/internal/router/core/onboarding.go, docs/components/
// gateway/web.md's Phase 2/3) — POST/GET /onboard, mounted directly on the
// router's own root, not behind /gateway or /brain like lib/gateway.ts and
// lib/api.ts. Same "pass a live getToken() rather than a cached token"
// shape as lib/gateway.ts: the router verifies the raw Clerk session JWT on
// every request, same as the Gateway does.
//
// 2026-09-25: no tenant_slug/request_id fields anymore — tenant identity is
// derived entirely from the caller's own Clerk user id
// (agent-harness/workflows/internal/tenantid.SlugForSub), and a signed-in
// user only ever has one onboarding workflow (their own), so there's
// nothing left to name or disambiguate on this side either.

export type LLMTier = {
  provider: 'openai' | 'anthropic'
  model: string
  apiKey: string
  baseURL: string
}

export type OnboardingSubmission = {
  // Only the tiers the person brought themselves. Empty means "use the platform's defaults": the automation worker then
  // leaves the tenant chart's own llm tiers in place and overrides just the tiers sent here.
  llmTiers: Record<string, LLMTier>
  postgresPassword: string
  agentBrainDbPassword: string
  agentBrainApiKey: string
  agentBrainJwtSecret: string
  mcpHubDbPassword: string
  // Optional — omit to use the platform's own shared embedding model (the
  // backend's chart default). Only set this when the user brought their own
  // external embedding endpoint; this cluster's embedding service has no
  // per-tenant key system to generate a real per-tenant value from
  // otherwise (workflows/internal/automation/activities/helm.go's
  // buildTenantValues).
  litellmApiKey?: string
}

export type OnboardingStep = {
  step: string
  status: 'running' | 'done' | 'failed'
  message: string
  updated_at: string
}

export type OnboardingStatus = {
  status: 'pending' | 'running' | 'awaiting_approval' | 'completed' | 'failed'
  error: string
  steps: OnboardingStep[]
}

export class OnboardingError extends Error {
  status: number
  constructor(message: string, status: number) {
    super(message)
    this.status = status
  }
}

// `||`, not `??`, matching lib/gateway.ts's own GATEWAY_BASE reasoning — an
// unset build-time override still reaches here as "" via the Dockerfile's
// own ENV default, not undefined.
const ROUTER_BASE = ((typeof window !== 'undefined' && window.__RUNTIME_CONFIG__?.ROUTER_BASE_URL) || '').replace(/\/$/, '')

type TokenGetter = () => Promise<string | null>

async function parseOnboardingError(res: Response): Promise<string> {
  try {
    const data = await res.json()
    if (typeof data?.error === 'string') {
      return data.error
    }
  } catch {
    // ignore
  }
  return res.statusText || 'request failed'
}

export async function submitOnboarding(
  getToken: TokenGetter,
  submission: OnboardingSubmission,
): Promise<{ status: string }> {
  const token = await getToken()
  if (!token) {
    throw new OnboardingError('not signed in', 401)
  }
  const res = await fetch(`${ROUTER_BASE}/onboard`, {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({
      llm_tiers: submission.llmTiers,
      postgres_password: submission.postgresPassword,
      agent_brain_db_password: submission.agentBrainDbPassword,
      agent_brain_api_key: submission.agentBrainApiKey,
      agent_brain_jwt_secret: submission.agentBrainJwtSecret,
      mcp_hub_db_password: submission.mcpHubDbPassword,
      litellm_api_key: submission.litellmApiKey || '',
    }),
  })
  if (!res.ok) {
    throw new OnboardingError(await parseOnboardingError(res), res.status)
  }
  return (await res.json()) as { status: string }
}

export async function getOnboardingStatus(getToken: TokenGetter): Promise<OnboardingStatus> {
  const token = await getToken()
  if (!token) {
    throw new OnboardingError('not signed in', 401)
  }
  const res = await fetch(`${ROUTER_BASE}/onboard`, {
    headers: {
      Accept: 'application/json',
      Authorization: `Bearer ${token}`,
    },
  })
  if (!res.ok) {
    throw new OnboardingError(await parseOnboardingError(res), res.status)
  }
  return (await res.json()) as OnboardingStatus
}

// Post-onboarding model edits (router/internal/core/llm.go): GET /llm never
// returns keys, only `hasKey`; PUT /llm with a blank apiKey keeps the stored
// one. The change is a helm upgrade, so progress is polled like onboarding.
export type LLMTierView = { provider: LLMTier['provider']; model: string; baseURL: string; hasKey: boolean }

async function routerFetch<T>(getToken: TokenGetter, path: string, init?: RequestInit): Promise<T> {
  const token = await getToken()
  if (!token) {
    throw new OnboardingError('not signed in', 401)
  }
  const res = await fetch(`${ROUTER_BASE}${path}`, {
    ...init,
    headers: { Accept: 'application/json', 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
  })
  if (!res.ok) {
    throw new OnboardingError(await parseOnboardingError(res), res.status)
  }
  return (await res.json()) as T
}

export async function getLLM(getToken: TokenGetter): Promise<Record<string, LLMTierView>> {
  return (await routerFetch<{ llm_tiers: Record<string, LLMTierView> }>(getToken, '/llm')).llm_tiers ?? {}
}

export function updateLLM(getToken: TokenGetter, llmTiers: Record<string, LLMTier>) {
  return routerFetch<{ status: string }>(getToken, '/llm', { method: 'PUT', body: JSON.stringify({ llm_tiers: llmTiers }) })
}

export function getLLMUpdateStatus(getToken: TokenGetter) {
  return routerFetch<OnboardingStatus>(getToken, '/llm/update')
}

// generateSecret produces a URL-safe random string suitable for pre-filling
// the onboarding form's infra-secret fields (Postgres/JWT/etc. passwords) —
// the user can accept it as-is or edit it; this only picks the default.
// crypto.getRandomValues, not Math.random — a real secret, not a UI
// placeholder.
export function generateSecret(bytes = 24): string {
  const arr = new Uint8Array(bytes)
  crypto.getRandomValues(arr)
  let binary = ''
  for (const b of arr) {
    binary += String.fromCharCode(b)
  }
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}
