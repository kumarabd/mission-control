export type ExplorerOverview = {
  bank_count: number
  entity_count: number
  memory_unit_count: number
  memory_unit_by_network?: Record<string, number>
  mental_model_count: number
}

export type RawTableGroup = 'episodic' | 'semantic' | 'meta'

export type RawTableInfo = {
  name: string
  label: string
  group: RawTableGroup
}

export type RawTableRowsResponse = {
  table: string
  columns: string[]
  items: Record<string, unknown>[]
  limit: number
  offset: number
}

export type AuditEntry = {
  id: string
  user_id: string
  agent_id: string
  session_id: string
  operation: string
  memory_id?: string | null
  signal_type?: string
  detail?: unknown
  created_at: string
}

export type ReadyzResponse = {
  ready: boolean
  checks: Record<string, string>
  degraded: string[]
}

/** Purpose-built, entity-joined memory reads (agent-brain's /v1/explorer/memory/*
 * — distinct from the generic /raw/{table} browser this page otherwise uses). */
export type MemoryEntityRef = {
  id: string
  name: string
}

export type MemoryFactItem = {
  id: string
  text: string
  network: string
  mention_time: string
  entities: MemoryEntityRef[]
}

export type MemoryFactsPage = {
  bank_available: boolean
  items: MemoryFactItem[]
  has_more: boolean
  limit: number
  offset: number
}

export type MemoryLinkedUnit = {
  id: string
  text: string
  network: string
  link_type: string
  weight: number
  direction: string
}

/* ---------- agent-brain semantic memory ---------- */

export type SemanticEntityRef = { id: string; name: string }

export type SemanticSourceRef = { id: string; title: string; available: boolean }

export type SemanticMemoryItem = {
  id: string
  kind: string
  title: string
  content?: string | null
  updated_at?: string | null
  created_at: string
  /** complete | partial | unavailable */
  availability: string
  /** recorded | not_recorded | partly_available */
  source_status: string
  entities: SemanticEntityRef[]
  truncated: boolean
  sources?: SemanticSourceRef[]
}

export type SemanticMemoryPage = {
  schema_version: number
  section: string
  retrieved_at: string
  bank_available: boolean
  items: SemanticMemoryItem[]
  has_more: boolean
  offset: number
  limit: number
}

/* ---------- agent-brain world model ---------- */

/** One entity: its free-form type and attributes come from the assistant, so they are shown, never switched on. */
export type WorldNode = {
  /** "entity:<uuid>" */
  id: string
  kind: string
  /** The profile's type, when one has been built. */
  subtype?: string
  label: string
  attributes?: Record<string, string>
  mention_count: number
}

export type WorldEdge = {
  from: string
  to: string
  type: string
  /** The predicate, for example works_at. */
  label: string
  source_count: number
}

export type SemanticWorldGraph = {
  schema_version: number
  retrieved_at: string
  bank_available: boolean
  nodes: WorldNode[]
  edges: WorldEdge[]
  truncated: boolean
  limit: number
}

export type MemoryUnitLinksResponse = {
  unit_id: string
  unit_text: string
  unit_network: string
  links: MemoryLinkedUnit[]
}
