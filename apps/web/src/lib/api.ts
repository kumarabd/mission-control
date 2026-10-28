import {
  agentsFromSettings,
  type AgentsSettingsResponse,
  type APIKeyCreateResponse,
  type APIKeyListResponse,
  type MeResponse,
  type RegisterAgentRequest,
  type RegisterAgentResponse,
  type TokenMintResponse,
} from './settingsTypes'
import {
  listValidators,
  normalizeAgentsSettings,
  normalizeItems,
  normalizeMemoryFactsPage,
  normalizeMemoryUnitLinks,
  normalizeOverview,
  normalizeRawTableInfo,
  normalizeRawTableRows,
  normalizeSemanticMemoryItem,
  normalizeSemanticMemoryPage,
  normalizeSemanticWorld,
  recordStringMap,
} from './safe'
import type {
  AuditEntry,
  ExplorerOverview,
  MemoryFactsPage,
  MemoryUnitLinksResponse,
  RawTableInfo,
  RawTableRowsResponse,
  ReadyzResponse,
  SemanticMemoryItem,
  SemanticMemoryPage,
  SemanticWorldGraph,
} from './types'
import { fetchWithTimeout, RequestTimeoutError } from './request'
import { fixtureEnabled } from './devFixture'
import { parsePerformanceMetrics, type PerformanceMetrics } from './metrics'
import { API_KEY_STORAGE_KEY, TOKEN_STORAGE_KEY } from '../auth/storage'

export { API_KEY_STORAGE_KEY, TOKEN_STORAGE_KEY }
export const AGENT_ID_STORAGE_KEY = 'explorer.agentId'

export class ApiError extends Error {
  status: number

  constructor(message: string, status: number) {
    super(message)
    this.status = status
  }
}

// The router (agent-harness's workflows/internal/router/core/proxy.go)
// answers 404 {"error":"no_tenant"} for a signed-in Clerk user whose
// organization has no row in tenant_registry yet — parseError's own
// `data.error` extraction below surfaces that literal string as this
// ApiError's message. AuthProvider.tsx checks this to redirect to /setup
// (the new-workspace flow) instead of showing a loading skeleton forever.
export function isNoTenantError(err: unknown): boolean {
  return err instanceof ApiError && err.status === 404 && err.message === 'no_tenant'
}

let unauthorizedHandler: (() => void) | null = null

export function setUnauthorizedHandler(handler: (() => void) | null) {
  unauthorizedHandler = handler
}

// Set by AuthProvider.tsx while a Clerk session is active — every
// router-proxied call sends the *live* Clerk token, fetched fresh per
// request (Clerk's own getToken() caches/refreshes internally, this is
// cheap to call every time). 2026-09-26: there used to be a one-time
// exchangeClerkSession() that swapped this for agent-brain's own
// self-minted session token, stored in TOKEN_STORAGE_KEY and reused for
// every later call. That broke the moment the shared router started
// verifying every /brain/ and /gateway/ request as a genuine Clerk JWT
// itself — agent-brain's token was never one, so the router rejected it
// before agent-brain (which would have accepted it fine) ever saw it.
// Removed entirely: agent-brain now trusts the router's own verified
// identity instead of holding a session store of its own.
let clerkTokenGetter: (() => Promise<string | null>) | null = null

export function setClerkTokenGetter(getter: (() => Promise<string | null>) | null) {
  clerkTokenGetter = getter
}

// 'web' — the actual, truthful default: every Explorer API call from this
// app IS the web Explorer UI, a single fixed identity, not a stand-in for
// some other real tool. The old default here ('cursor-agent', a genuinely
// different, external tool's own name) was never set BY anything under
// Clerk auth — only Login.tsx's dev-only legacy form ever writes
// AGENT_ID_STORAGE_KEY — so every real Clerk user's calls were silently
// mislabeled as coming from a tool they never used. Doesn't distinguish
// *which* human is behind a given call, only that it came through this
// manual UI rather than an automated tool — still a real, useful signal in
// agent-brain's own audit trail. Still overridable via localStorage for
// local dev/testing agent-brain's own per-agent write-ACL policies
// (EntityWriteACLSection.tsx).
export const DEFAULT_AGENT_ID = 'web'

async function authHeaders(): Promise<HeadersInit> {
  const headers: Record<string, string> = {
    Accept: 'application/json',
    'X-Agent-Id': localStorage.getItem(AGENT_ID_STORAGE_KEY) || DEFAULT_AGENT_ID,
  }
  if (clerkTokenGetter) {
    const clerkToken = await clerkTokenGetter()
    if (clerkToken) {
      headers.Authorization = `Bearer ${clerkToken}`
    }
    return headers
  }
  // No Clerk session active — legacy/self-hosted mode, where the operator
  // pastes a long-lived credential directly (Login.tsx's dev form) and
  // agent-brain verifies it itself (no shared router in front).
  const token = localStorage.getItem(TOKEN_STORAGE_KEY)?.trim()
  if (token) {
    headers.Authorization = `Bearer ${token}`
  }
  const apiKey = localStorage.getItem(API_KEY_STORAGE_KEY)?.trim()
  if (apiKey) {
    headers['X-API-Key'] = apiKey
  }
  return headers
}

/**
 * Identity headers for router-proxied engines such as Life Engine. They verify
 * the Clerk token themselves; the Explorer-only X-Agent-Id header is omitted.
 */
export async function getRouterAuthHeaders(): Promise<Record<string, string>> {
  const headers: Record<string, string> = { Accept: 'application/json' }
  if (clerkTokenGetter) {
    const clerkToken = await clerkTokenGetter()
    if (clerkToken) headers.Authorization = `Bearer ${clerkToken}`
    return headers
  }
  const token = localStorage.getItem(TOKEN_STORAGE_KEY)?.trim()
  if (token) headers.Authorization = `Bearer ${token}`
  const apiKey = localStorage.getItem(API_KEY_STORAGE_KEY)?.trim()
  if (apiKey) headers['X-API-Key'] = apiKey
  return headers
}

// window.__RUNTIME_CONFIG__.AGENT_BRAIN_API_URL wins when present — see
// gateway.ts's own comment/`declare global` for the full reasoning
// (2026-09-24, replacing the removed nginx /v1/ proxy). `??`, not `||`,
// preserved from before: an explicit empty-string VITE_API_BASE_URL build
// override still means "same-origin", distinct from "unset".
const API_BASE = (
  window.__RUNTIME_CONFIG__?.AGENT_BRAIN_API_URL ??
  import.meta.env.VITE_API_BASE_URL ??
  ''
).replace(/\/$/, '')

function apiPath(path: string): string {
  if (!path.startsWith('/')) {
    return `${API_BASE}/${path}`
  }
  return `${API_BASE}${path}`
}

async function parseError(res: Response): Promise<string> {
  try {
    const data = await res.json()
    if (typeof data?.error === 'string') {
      return data.error
    }
  } catch {
    // ignore
  }
  return res.statusText || 'Request failed'
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const headers = {
    ...(await authHeaders()),
    ...(init?.headers || {}),
  }

  let res: Response
  try {
    res = await fetchWithTimeout(apiPath(path), { ...init, headers })
  } catch (error) {
    if (error instanceof RequestTimeoutError) throw new ApiError(error.message, 408)
    throw error
  }

  if (!res.ok) {
    if (res.status === 401 && unauthorizedHandler) {
      unauthorizedHandler()
    }
    throw new ApiError(await parseError(res), res.status)
  }
  return (await res.json()) as T
}

async function listItems<T>(
  path: string,
  isValid: (item: T) => boolean,
): Promise<{ items: T[] }> {
  const res = await request<{ items?: (T | null)[] | null }>(path)
  return { items: normalizeItems(res.items ?? undefined, isValid) }
}

export async function getOverview(): Promise<ExplorerOverview> {
  const data = await request<ExplorerOverview>('/v1/explorer/overview')
  return normalizeOverview(data)
}

export function getAudit(operation?: string) {
  const q = new URLSearchParams()
  q.set('limit', '200')
  if (operation) q.set('operation', operation)
  return listItems<AuditEntry>(`/v1/explorer/audit?${q.toString()}`, listValidators.audit)
}

export async function getSystemStatus() {
  const res = await request<{ degraded?: Record<string, string> | null; embeddings_available?: boolean }>(
    '/v1/explorer/system-status',
  )
  return {
    degraded: recordStringMap(res.degraded),
    embeddings_available: Boolean(res.embeddings_available),
  }
}

export async function getRawTables(): Promise<{ items: RawTableInfo[] }> {
  const res = await request<{ items?: unknown[] | null }>('/v1/explorer/raw')
  return {
    items: (res.items ?? [])
      .map(normalizeRawTableInfo)
      .filter((r): r is RawTableInfo => r != null),
  }
}

export type RawTableRowsFilter = {
  limit?: number
  offset?: number
}

export async function getRawTableRows(
  table: string,
  filter: RawTableRowsFilter = {},
): Promise<RawTableRowsResponse> {
  const q = new URLSearchParams()
  q.set('limit', String(filter.limit ?? 50))
  q.set('offset', String(filter.offset ?? 0))
  const raw = await request<unknown>(`/v1/explorer/raw/${encodeURIComponent(table)}?${q.toString()}`)
  return normalizeRawTableRows(raw, table)
}

export type MemoryFactsFilter = {
  network?: string
  entityId?: string
  limit?: number
  offset?: number
}

/** Entity-joined facts — a purpose-built drill-down, distinct from the raw
 * /raw/memory_unit browser this page's primary list otherwise uses. */
export async function getMemoryFacts(filter: MemoryFactsFilter = {}): Promise<MemoryFactsPage> {
  if (import.meta.env.DEV && fixtureEnabled() && filter.entityId) {
    const { fixtureEntityFacts } = await import('./life/devFixtures')
    return fixtureEntityFacts(filter.entityId)
  }
  const q = new URLSearchParams()
  if (filter.network) q.set('network', filter.network)
  if (filter.entityId) q.set('entity_id', filter.entityId)
  q.set('limit', String(filter.limit ?? 50))
  q.set('offset', String(filter.offset ?? 0))
  const raw = await request<unknown>(`/v1/explorer/memory/facts?${q.toString()}`)
  return normalizeMemoryFactsPage(raw)
}

/** One memory unit's persisted memory_link edges plus live entity-derived
 * adjacency. Returns null for a unit outside the configured bank (404), same
 * "absent, not a thrown error" shape normalizeRawTableRows' own ok-bool callers use. */
export async function getMemoryUnitLinks(unitId: string): Promise<MemoryUnitLinksResponse | null> {
  try {
    const raw = await request<unknown>(`/v1/explorer/memory/units/${encodeURIComponent(unitId)}/links`)
    return normalizeMemoryUnitLinks(raw)
  } catch (err) {
    if (err instanceof ApiError && err.status === 404) return null
    throw err
  }
}

export type SemanticSection = 'reflections' | 'about_you'

export type SemanticMemoryFilter = {
  q?: string
  limit?: number
  offset?: number
}

/**
 * agent-brain's read-only semantic projection. A 404 here means this
 * workspace's memory service predates the semantic views (upgrade needed),
 * not that memory is empty.
 */
export async function getSemanticMemory(
  section: SemanticSection,
  filter: SemanticMemoryFilter = {},
): Promise<SemanticMemoryPage> {
  const limit = filter.limit ?? 20
  const offset = filter.offset ?? 0
  if (import.meta.env.DEV && fixtureEnabled()) {
    const { fixtureSemanticPage } = await import('./life/devFixtures')
    return fixtureSemanticPage(section, offset, limit)
  }
  const q = new URLSearchParams({
    section,
    q: filter.q ?? '',
    limit: String(limit),
    offset: String(offset),
  })
  const raw = await request<unknown>(`/v1/explorer/semantic?${q.toString()}`)
  const page = normalizeSemanticMemoryPage(raw, section, offset)
  if (!page) {
    throw new ApiError('Your memory returned an unreadable response. Try again later.', 502)
  }
  return page
}

/**
 * The world model: entities with their profiles and the typed relations among them. A 404 means this workspace's
 * memory service predates the world view (upgrade needed), not that the world is empty.
 */
export async function getSemanticWorld(limit = 100): Promise<SemanticWorldGraph> {
  if (import.meta.env.DEV && fixtureEnabled()) {
    const { fixtureSemanticWorld } = await import('./life/devFixtures')
    return fixtureSemanticWorld()
  }
  const raw = await request<unknown>(`/v1/explorer/semantic/world?${new URLSearchParams({ limit: String(limit) }).toString()}`)
  const world = normalizeSemanticWorld(raw)
  if (!world) {
    throw new ApiError('Your memory returned an unreadable response. Try again later.', 502)
  }
  return world
}

/** One supporting memory behind a semantic item. 404 means it is no longer available. */
export async function getSemanticSource(
  parent: string,
  source: string,
): Promise<SemanticMemoryItem> {
  if (import.meta.env.DEV && fixtureEnabled()) {
    const { fixtureSemanticSource } = await import('./life/devFixtures')
    return fixtureSemanticSource(source)
  }
  const q = new URLSearchParams({ parent, source })
  const raw = await request<unknown>(`/v1/explorer/semantic-source?${q.toString()}`)
  const item = normalizeSemanticMemoryItem(raw)
  if (!item || item.id !== source) {
    throw new ApiError('This supporting memory is no longer available.', 404)
  }
  return item
}

export async function getReadyz() {
  let res: Response
  try {
    res = await fetchWithTimeout(apiPath('/readyz'), { headers: await authHeaders() })
  } catch (error) {
    if (error instanceof RequestTimeoutError) throw new ApiError(error.message, 408)
    throw error
  }
  if (!res.ok) {
    throw new ApiError(await parseError(res), res.status)
  }
  const data = (await res.json()) as ReadyzResponse
  return {
    ...data,
    checks: data.checks ?? {},
    degraded: Array.isArray(data.degraded) ? data.degraded : [],
  }
}

/** Read the deployment's Prometheus exposition endpoint when it is available. */
export async function getPerformanceMetrics(): Promise<PerformanceMetrics> {
  let res: Response
  try {
    res = await fetchWithTimeout('/metrics', { headers: await authHeaders() })
  } catch (error) {
    if (error instanceof RequestTimeoutError) throw new ApiError(error.message, 408)
    throw error
  }
  if (!res.ok) throw new ApiError(await parseError(res), res.status)
  return parsePerformanceMetrics(await res.text())
}

export async function getSettingsAgents() {
  const data = await request<AgentsSettingsResponse>('/v1/explorer/settings/agents')
  return normalizeAgentsSettings(data) ?? data
}

export async function registerAgent(body: RegisterAgentRequest) {
  return request<RegisterAgentResponse>('/v1/explorer/settings/agents', {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
}

export async function listAPIKeys() {
  const res = await request<APIKeyListResponse>('/v1/explorer/settings/api-keys')
  const keys = Array.isArray(res.keys)
    ? res.keys.filter(
        (k): k is APIKeyListResponse['keys'][number] =>
          Boolean(k && typeof k === 'object' && typeof k.id === 'string' && typeof k.prefix === 'string'),
      )
    : []
  return { ...res, keys }
}

export async function revokeAPIKey(keyId: string) {
  return request<{ id: string; message: string }>(
    `/v1/explorer/settings/api-keys/${encodeURIComponent(keyId)}`,
    { method: 'DELETE' },
  )
}

export async function deleteAgent(agentId: string) {
  return request<{ agent_id: string; message: string }>(
    `/v1/explorer/settings/agents/${encodeURIComponent(agentId)}`,
    { method: 'DELETE' },
  )
}

export async function updateEntityWriteACL(entityWriteACL: Record<string, string[]>) {
  return request<{ subject_write_acl: Record<string, string[]>; message: string }>(
    '/v1/explorer/settings/entity-write-acl',
    {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ subject_write_acl: entityWriteACL }),
    },
  )
}

export async function createAPIKey() {
  return request<APIKeyCreateResponse>('/v1/explorer/settings/api-keys', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: '{}',
  })
}

export async function mintToken(ttlHours = 24) {
  return request<TokenMintResponse>('/v1/explorer/settings/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ ttl_hours: ttlHours }),
  })
}

export async function getMe() {
  const res = await request<MeResponse>('/v1/explorer/me')
  return {
    ...res,
    onboarding: {
      ...res.onboarding,
      agents: agentsFromSettings({
        user_id: res.user_id,
        suggested_agent_id: '',
        agents: res.onboarding?.agents ?? null,
      }),
    },
  }
}

const PLUGINS_RAW_BASE =
  'https://raw.githubusercontent.com/realnighthawk/agent-plugins/main'

export type InstallPlatform = 'cursor' | 'claude_code' | 'openclaw' | 'hermes'

export function installScriptUrlForPlatform(platform: InstallPlatform): string {
  const path =
    platform === 'claude_code'
      ? 'plugins/claude-code/install.sh'
      : platform === 'openclaw'
        ? 'plugins/openclaw/install.sh'
        : platform === 'hermes'
          ? 'plugins/hermes/install.sh'
          : 'plugins/cursor/install.sh'
  return `${import.meta.env.VITE_PLUGINS_RAW_BASE || PLUGINS_RAW_BASE}/${path}`
}

function shellQuote(value: string): string {
  return value.replace(/'/g, "'\\''")
}

export function buildInstallCurlCommand(opts: {
  installScriptUrl: string
  mcpUrl: string
  agentId: string
  apiKey?: string
  jwt?: string
  global?: boolean
  restart?: boolean
}): string {
  const args: string[] = []
  if (opts.global) {
    args.push('--global')
  }
  args.push(`--url ${opts.mcpUrl}`, `--agent-id ${opts.agentId}`)
  const key = opts.apiKey?.trim()
  if (key && key !== 'YOUR_KEY' && key !== 'YOUR_API_KEY') {
    args.push(`--api-key '${shellQuote(key)}'`)
  } else if (opts.jwt?.trim()) {
    args.push(`--jwt '${shellQuote(opts.jwt.trim())}'`)
  } else {
    args.push('--api-key YOUR_KEY')
  }
  if (opts.restart) {
    args.push('--restart')
  }
  return `curl -fsSL ${opts.installScriptUrl} | bash -s -- ${args.join(' \\\n  ')}`
}

export function buildInstallCurlCommandForPlatform(
  platform: InstallPlatform,
  opts: {
    mcpUrl: string
    agentId: string
    apiKey?: string
    jwt?: string
    installScriptUrl?: string
  },
): string {
  return buildInstallCurlCommand({
    installScriptUrl: opts.installScriptUrl ?? installScriptUrlForPlatform(platform),
    mcpUrl: opts.mcpUrl,
    agentId: opts.agentId,
    apiKey: opts.apiKey,
    jwt: opts.jwt,
    global: platform === 'cursor',
    restart: platform === 'openclaw',
  })
}

export function buildClaudeEnvBlock(opts: {
  mcpUrl: string
  agentId: string
  apiKey: string
}): string {
  return buildInstallCurlCommandForPlatform('claude_code', opts)
}

export function buildOpenClawConfigSnippet(opts: {
  mcpUrl: string
  agentId: string
  apiKey: string
}): string {
  return buildInstallCurlCommandForPlatform('openclaw', opts)
}

export function updateScriptUrlForPlatform(platform: InstallPlatform): string {
  const path =
    platform === 'claude_code'
      ? 'plugins/claude-code/update.sh'
      : platform === 'openclaw'
        ? 'plugins/openclaw/update.sh'
        : platform === 'hermes'
          ? 'plugins/hermes/update.sh'
          : 'plugins/cursor/update.sh'
  return `${import.meta.env.VITE_PLUGINS_RAW_BASE || PLUGINS_RAW_BASE}/${path}`
}

export function buildUpdateCurlCommandForPlatform(
  platform: InstallPlatform,
  opts: {
    mcpUrl: string
    agentId: string
    apiKey?: string
    jwt?: string
  },
): string {
  const scriptUrl = updateScriptUrlForPlatform(platform)
  if (platform === 'cursor') {
    return `curl -fsSL ${scriptUrl} | bash`
  }
  if (platform === 'openclaw') {
    return `curl -fsSL ${scriptUrl} | bash -s -- --restart`
  }
  return buildInstallCurlCommand({
    installScriptUrl: scriptUrl,
    mcpUrl: opts.mcpUrl,
    agentId: opts.agentId,
    apiKey: opts.apiKey,
    jwt: opts.jwt,
  })
}
