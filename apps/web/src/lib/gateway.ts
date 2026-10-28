// Client for workflows/cmd/gateway (docs/components/gateway/web.md) — the
// chat page's own backend. Deliberately separate from lib/api.ts: that file
// talks to agent-brain's explorer API under its own token-exchange auth
// scheme (localStorage-cached bearer token, X-Agent-Id headers); the Gateway
// instead verifies the raw Clerk session JWT directly on every request (its
// own auth.go's requireClerkAuth), so callers here pass a live
// `getToken()` rather than reading anything out of localStorage.
import { fetchWithTimeout, RequestTimeoutError } from './request'
import { getRouterAuthHeaders } from './api'
import { fixtureEnabled } from './devFixture'
//
// The HTTP endpoints remain the recovery/fallback surface. Live Chat uses the
// resumable /web/ws stream; its cursor is scoped to the selected Web session.

export type PolledTurn = {
  turn_seq: number
  turn_id: string
  status: 'completed' | 'cancelled' | 'failed'
  user_content: string
  content: string
  tool_calls?: PolledToolCall[] | null
}

export type PolledToolCall = {
  tool_call_id: string
  message_seq: number
  tool_name: string
  arguments: unknown
  status: 'pending' | 'ok' | 'error' | 'cancelled'
  result?: unknown
  started_at?: string
  completed_at?: string
}

export type PendingInput = {
  request_id: string
  kind: string
  prompt: string
  options: { id: string; label: string }[]
  allow_free_text: boolean
}

export type PollResult = {
  turns: PolledTurn[]
  pending_input: PendingInput | null
}

export type SessionSummary = {
  session_id: string
  parent_session_id: string | null
  created_at: string
  updated_at: string
  title: string
  preview: string
  is_running: boolean
}

export class GatewayError extends Error {
  status: number

  constructor(message: string, status: number) {
    super(message)
    this.status = status
  }
}

// window.__RUNTIME_CONFIG__ — rendered into runtime-config.js at container
// start from ROUTER_PUBLIC_URL (docker/runtime-config.js.template,
// docker-entrypoint.sh), loaded by index.html ahead of this bundle.
// Ambient-declared here (no separate .d.ts file in this repo); visible
// program-wide since `declare global` augments the global scope, not just
// this file's own.
declare global {
  interface Window {
    __RUNTIME_CONFIG__?: {
      GATEWAY_API_URL?: string
      AGENT_BRAIN_API_URL?: string
      // Bare router origin, no /gateway or /brain prefix — src/lib/onboarding.ts.
      ROUTER_BASE_URL?: string
    }
  }
}

// Runtime config (the router's real, per-deployment public URL) wins when
// present — 2026-09-24, replacing the removed nginx /gateway/ proxy
// (agent-harness/docs/components/gateway/web.md, "Resolved: Shared
// agent-web + Identity-Routing Router"). Falls back to the Vite build-time
// override, then same-origin `/gateway` — that same-origin default is now
// mostly a `vite dev`-only convenience (this image's own nginx no longer
// serves anything at /gateway/ itself), not a real production path.
// `||`, not `??`, throughout: the Dockerfile always sets VITE_GATEWAY_BASE_URL
// (even to ""), so an unset override reaches here as an empty string, not
// undefined; `??` would never fall through in that case.
const GATEWAY_BASE = (
  window.__RUNTIME_CONFIG__?.GATEWAY_API_URL ||
  import.meta.env.VITE_GATEWAY_BASE_URL ||
  '/gateway'
).replace(/\/$/, '')

// 2026-09-25: connections moved off the Gateway's own base entirely — the
// router now mounts them at their own top-level /connections/ prefix
// (workflows/internal/router/core/proxy.go), forwarding to each tenant's
// own per-namespace connections service, not something Gateway itself
// serves. Bare router origin (window.__RUNTIME_CONFIG__.ROUTER_BASE_URL,
// same one src/lib/onboarding.ts uses) + "/connections", not GATEWAY_BASE.
const CONNECTIONS_BASE = (
  (window.__RUNTIME_CONFIG__?.ROUTER_BASE_URL ? `${window.__RUNTIME_CONFIG__.ROUTER_BASE_URL}/connections` : '') ||
  '/connections'
).replace(/\/$/, '')

type TokenGetter = () => Promise<string | null>

// 2026-09-26: this shape now matches mcp-hub's own GET /api/catalog directly
// (mcp-hub/src/mcp_hub/server.py's catalog_list) — there is no more
// intermediate "connections" Go service with its own desired_state/actual-
// state distinction. Connecting/disconnecting is immediate: mcp-hub either
// has the backend registered or it doesn't, so "state"/"tool_count" are only
// present once `connected` is true (mcp-hub is still polling/indexing it).
export type CatalogItem = {
  name: string
  display_name: string
  description: string
  auth_kind: 'none' | 'header' | 'oauth'
  // Only meaningful when auth_kind === 'oauth'. "authorization_code" (the
  // default) needs no secret up front — a browser consent step provisions
  // one. "client_credentials" (e.g. Trek) is a machine client: there is no
  // browser step at all, so the caller must supply client_id/client_secret
  // themselves at connect time instead of authorizing afterward.
  oauth_grant_type?: 'authorization_code' | 'client_credentials'
  // "in-house" = built by us; shown with a marker on the card.
  origin?: 'in-house' | 'third-party'
  // One platform-wide instance/account the tenant doesn't own: there is
  // nothing of their own to enter, but it is NOT "no credentials required".
  shared?: boolean
  tags?: string[]
  connected: boolean
  state?: 'indexing' | 'ready' | 'needs_authorization' | 'failed'
  tool_count?: number
}

// Builds a browser WebSocket URL from the same configurable base used by the
// HTTP client. In development Vite strips /gateway and forwards this to the
// Gateway's GET /web/ws route; production can point VITE_GATEWAY_BASE_URL at
// an HTTPS Gateway origin and gets WSS automatically.
//
// `token` rides along as a query parameter, not a header — the native
// WebSocket API has no way to set one on the upgrade request. This is only
// for the shared router's own tenant-routing check (proxy.go's
// authenticateUser); Gateway itself still authenticates independently via
// the `type: "auth"` first frame this same token is also sent in.
export function realtimeGatewayUrl(token: string): string {
  const url = new URL(`${GATEWAY_BASE}/web/ws`, window.location.origin)
  url.protocol = url.protocol === 'https:' ? 'wss:' : 'ws:'
  url.searchParams.set('token', token)
  return url.toString()
}

async function gatewayRequest<T>(
  getToken: TokenGetter,
  path: string,
  init?: RequestInit,
): Promise<T> {
  const token = await getToken()
  if (!token) {
    throw new GatewayError('not signed in', 401)
  }
  let res: Response
  try {
    res = await fetchWithTimeout(`${GATEWAY_BASE}${path}`, {
      ...init,
      headers: {
        Accept: 'application/json',
        Authorization: `Bearer ${token}`,
        ...(init?.headers || {}),
      },
    })
  } catch (error) {
    if (error instanceof RequestTimeoutError) throw new GatewayError(error.message, 408)
    throw error
  }
  if (!res.ok) {
    const text = await res.text().catch(() => '')
    throw new GatewayError(text || res.statusText || 'request failed', res.status)
  }
  if (res.status === 204) return undefined as T
  const text = await res.text().catch(() => '')
  if (!text) return undefined as T
  return JSON.parse(text) as T
}

/* ---------- notification inbox ---------- */

export type NotificationLink = { entity: string; id: string }

export type GatewayNotification = {
  id: string
  source: string
  kind: string
  title: string
  body: string
  priority: string
  link?: NotificationLink | null
  session_id?: string | null
  created_at: string
  read_at?: string | null
}

export type NotificationsPage = {
  items: GatewayNotification[]
  unread: number
  next_before: string | null
}

export const NOTIFICATION_LINK_ENTITIES = ['goal', 'routine', 'reminder', 'plan_item'] as const

function normalizeNotification(raw: unknown): GatewayNotification | null {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null
  const r = raw as Record<string, unknown>
  if (typeof r.id !== 'string' || typeof r.title !== 'string') return null
  let link: NotificationLink | null = null
  if (r.link && typeof r.link === 'object' && !Array.isArray(r.link)) {
    const l = r.link as Record<string, unknown>
    if (typeof l.entity === 'string' && typeof l.id === 'string') {
      link = { entity: l.entity, id: l.id }
    }
  }
  return {
    id: r.id,
    source: typeof r.source === 'string' ? r.source : '',
    kind: typeof r.kind === 'string' ? r.kind : '',
    title: r.title,
    body: typeof r.body === 'string' ? r.body : '',
    priority: typeof r.priority === 'string' ? r.priority : 'normal',
    link,
    session_id: typeof r.session_id === 'string' ? r.session_id : null,
    created_at: typeof r.created_at === 'string' ? r.created_at : '',
    read_at: typeof r.read_at === 'string' ? r.read_at : null,
  }
}

/** Newest first. `before` must be the previous page's `next_before`, verbatim. */
export async function listNotifications(
  options: { limit?: number; before?: string | null } = {},
): Promise<NotificationsPage> {
  const params = new URLSearchParams({ limit: String(options.limit ?? 50) })
  if (options.before) params.set('before', options.before)
  const page = await notificationRequest<{
    items?: unknown[] | null
    unread?: number
    next_before?: string | null
  }>(`/notifications?${params.toString()}`)
  return {
    items: (page.items ?? [])
      .map(normalizeNotification)
      .filter((item): item is GatewayNotification => item != null),
    unread: typeof page.unread === 'number' ? page.unread : 0,
    next_before: typeof page.next_before === 'string' ? page.next_before : null,
  }
}

export async function markNotificationRead(id: string): Promise<void> {
  await notificationRequest<void>(`/notifications/${encodeURIComponent(id)}/read`, {
    method: 'POST',
  })
}

export async function markAllNotificationsRead(): Promise<number> {
  const result = await notificationRequest<{ marked?: number }>('/notifications/read-all', {
    method: 'POST',
  })
  return typeof result.marked === 'number' ? result.marked : 0
}

/**
 * The inbox uses the same router auth headers as the rest of the console, so
 * it also works in a local build without Clerk. The Gateway still verifies the
 * Clerk JWT in every deployed environment.
 */
async function notificationRequest<T>(path: string, init?: RequestInit): Promise<T> {
  if (import.meta.env.DEV && fixtureEnabled()) {
    const { fixtureNotificationResponse } = await import('./life/devFixtures')
    return fixtureNotificationResponse(path, init?.method ?? 'GET') as T
  }
  let res: Response
  try {
    res = await fetchWithTimeout(`${GATEWAY_BASE}${path}`, {
      ...init,
      headers: {
        Accept: 'application/json',
        ...(await getRouterAuthHeaders()),
        ...(init?.headers || {}),
      },
    })
  } catch (error) {
    if (error instanceof RequestTimeoutError) throw new GatewayError(error.message, 408)
    throw error
  }
  if (!res.ok) {
    const text = await res.text().catch(() => '')
    throw new GatewayError(text || res.statusText || 'request failed', res.status)
  }
  if (res.status === 204) return undefined as T
  const text = await res.text().catch(() => '')
  if (!text) return undefined as T
  return JSON.parse(text) as T
}

// connectionsRequest mirrors gatewayRequest exactly but against
// CONNECTIONS_BASE instead — see that constant's own comment. Every path
// here is forwarded straight through to that tenant's own mcp-hub instance
// (the router's /connections/ prefix is a pure proxy — see proxy.go), except
// /{name}/authorize, which the router itself handles (see gateway/web.md's
// "Resolved: mcp-hub Owns Connections Entirely").
async function connectionsRequest<T>(
  getToken: TokenGetter,
  path: string,
  init?: RequestInit,
): Promise<T> {
  const token = await getToken()
  if (!token) {
    throw new GatewayError('not signed in', 401)
  }
  let res: Response
  try {
    res = await fetchWithTimeout(`${CONNECTIONS_BASE}${path}`, {
      ...init,
      headers: {
        Accept: 'application/json',
        Authorization: `Bearer ${token}`,
        ...(init?.headers || {}),
      },
    })
  } catch (error) {
    if (error instanceof RequestTimeoutError) throw new GatewayError(error.message, 408)
    throw error
  }
  if (!res.ok) {
    const text = await res.text().catch(() => '')
    throw new GatewayError(text || res.statusText || 'request failed', res.status)
  }
  if (res.status === 204) {
    return undefined as T
  }
  return (await res.json()) as T
}

export function listCatalog(getToken: TokenGetter) {
  return connectionsRequest<{ items: CatalogItem[] }>(getToken, '/api/catalog')
}

export type ConnectSecrets = {
  // For auth_kind "header" backends (e.g. GitHub, Exa).
  token?: string
  // For auth_kind "oauth" backends with oauth_grant_type "client_credentials"
  // (e.g. Trek) — a machine client with no browser consent step.
  oauth?: { client_id: string; client_secret: string; scopes?: string }
}

// name must match a GET /api/catalog entry's own name (e.g. "notion",
// "github", "trek"). Re-connecting without re-supplying a secret keeps
// whatever is already stored (mcp-hub's own merge-on-update behavior) —
// callers don't need to re-enter a token/client_secret just to retry.
export function connectCatalogEntry(getToken: TokenGetter, name: string, secrets?: ConnectSecrets) {
  return connectionsRequest<CatalogItem>(getToken, '/api/connections', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ name, token: secrets?.token || undefined, oauth: secrets?.oauth }),
  })
}

export function disconnectCatalogEntry(getToken: TokenGetter, name: string) {
  return connectionsRequest<void>(getToken, `/api/connections/${encodeURIComponent(name)}`, { method: 'DELETE' })
}

export function authorizeCatalogEntry(getToken: TokenGetter, name: string) {
  return connectionsRequest<{ authorization_url: string }>(getToken, `/${encodeURIComponent(name)}/authorize`, { method: 'POST' })
}

export async function sendMessage(
  getToken: TokenGetter,
  content: string,
  clientMessageId: string,
  sessionId?: string,
  parentSessionId?: string,
  agentId?: string,
): Promise<{ status: string }> {
  return gatewayRequest(getToken, '/send', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      content,
      client_message_id: clientMessageId,
      session_id: sessionId ?? null,
      parent_session_id: parentSessionId ?? null,
      agent_id: agentId ?? null,
    }),
  })
}

export async function pollTurns(
  getToken: TokenGetter,
  sinceTurnSeq: number,
  sessionId?: string,
): Promise<PollResult> {
  const params = new URLSearchParams({ since_turn_seq: String(sinceTurnSeq) })
  if (sessionId) {
    params.set('session_id', sessionId)
  }
  const res = await gatewayRequest<{ turns: PolledTurn[] | null; pending_input: PendingInput | null }>(
    getToken,
    `/poll?${params.toString()}`,
  )
  return { turns: res.turns ?? [], pending_input: res.pending_input ?? null }
}

export async function respondToInput(
  getToken: TokenGetter,
  requestId: string,
  answer: { selectedOptionId?: string; freeText?: string },
  sessionId?: string,
): Promise<{ status: string }> {
  return gatewayRequest(getToken, '/respond', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      request_id: requestId,
      selected_option_id: answer.selectedOptionId ?? null,
      free_text: answer.freeText ?? null,
      session_id: sessionId ?? null,
    }),
  })
}

export async function cancelTurn(
  getToken: TokenGetter,
  sessionId?: string,
): Promise<{ status: string }> {
  return gatewayRequest(getToken, '/cancel', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ session_id: sessionId ?? null }),
  })
}

export async function listSessions(getToken: TokenGetter): Promise<SessionSummary[]> {
  const res = await gatewayRequest<{ sessions: SessionSummary[] | null }>(getToken, '/sessions')
  return res.sessions ?? []
}

// The gateway's own agent registry (gateway/internal/agents) — called "Persona" here, deliberately: lib/api.ts
// already has an unrelated "agent" (agent-brain's write-ACL tool identities, e.g. registerAgent/AgentPolicyEntry),
// and reusing that name would collide in code search and in-product copy. The HTTP path is still the real
// /agents route; only the client-facing name differs.
// Which persona a new session should address — purely a client-side preference (no backend state), read by
// useGatewayThread when it opens a session and written by Settings > Personas. Empty/absent means the default
// agent (core.DefaultAgentID, resolved server-side), same convention the iOS client uses for its own selection.
export const SELECTED_PERSONA_STORAGE_KEY = 'agent-web.selectedAgentId'

export type Persona = {
  agent_id: string
  display_name: string
  avatar_url: string | null
  description: string
  persona: string
  status: 'active' | 'disabled'
  created_at: string
}

export async function listPersonas(getToken: TokenGetter): Promise<Persona[]> {
  const res = await gatewayRequest<{ agents: Persona[] | null }>(getToken, '/agents')
  return res.agents ?? []
}

export async function createPersona(
  getToken: TokenGetter,
  body: { display_name: string; persona?: string; description?: string; avatar_url?: string },
): Promise<Persona> {
  return gatewayRequest(getToken, '/agents', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
}

export async function updatePersona(
  getToken: TokenGetter,
  agentId: string,
  patch: Partial<Pick<Persona, 'display_name' | 'persona' | 'description' | 'avatar_url' | 'status'>>,
): Promise<Persona> {
  return gatewayRequest(getToken, `/agents/${encodeURIComponent(agentId)}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(patch),
  })
}

// The tenant gateway owns the skill catalog and its enabled state. The page
// displays every registered skill, including ones currently disabled.

export type Skill = {
  name: string
  description: string
  input_schema: Record<string, unknown>
  enabled: boolean
}

function parseSkill(value: unknown): Skill {
  if (!value || typeof value !== 'object') throw new GatewayError('Skill status is unavailable', 502)
  const skill = value as Record<string, unknown>
  if (typeof skill.name !== 'string' || !skill.name || typeof skill.enabled !== 'boolean') {
    throw new GatewayError('Skill status is unavailable', 502)
  }
  return {
    name: skill.name,
    description: String(skill.description ?? ''),
    enabled: skill.enabled,
    input_schema:
      skill.input_schema && typeof skill.input_schema === 'object'
        ? (skill.input_schema as Record<string, unknown>)
        : {},
  }
}

export async function listSkills(getToken: TokenGetter): Promise<Skill[]> {
  const res = await gatewayRequest<{ skills: unknown[] | null }>(getToken, '/skills')
  const skills = res.skills ?? []
  if (!Array.isArray(skills)) throw new GatewayError('Skill catalog is unavailable', 502)
  return skills.map(parseSkill)
}

export async function setSkillEnabled(getToken: TokenGetter, name: string, enabled: boolean): Promise<Skill> {
  const updated = await gatewayRequest<unknown>(getToken, `/skills/${encodeURIComponent(name)}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ enabled }),
  })
  const skill = parseSkill(updated)
  if (skill.name !== name || skill.enabled !== enabled) throw new GatewayError('Skill status was not confirmed', 502)
  return skill
}
