import type {
  AuditEntry,
  ExplorerOverview,
  MemoryEntityRef,
  MemoryFactItem,
  MemoryFactsPage,
  MemoryLinkedUnit,
  MemoryUnitLinksResponse,
  RawTableGroup,
  RawTableInfo,
  RawTableRowsResponse,
  SemanticEntityRef,
  SemanticMemoryItem,
  SemanticMemoryPage,
  SemanticSourceRef,
  SemanticWorldGraph,
  WorldEdge,
  WorldNode,
} from './types'
import { agentsFromSettings, type AgentsSettingsResponse } from './settingsTypes'

/** Drop null/invalid entries from API list payloads. */
export function normalizeItems<T>(
  items: (T | null | undefined)[] | null | undefined,
  isValid: (item: T) => boolean,
): T[] {
  if (!items) {
    return []
  }
  return items.filter((item): item is T => item != null && isValid(item))
}

export function recordStringMap(
  value: Record<string, string> | null | undefined,
): Record<string, string> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return {}
  }
  return value
}

export function hasStringId(item: { id?: string | null }): boolean {
  return typeof item?.id === 'string' && item.id.length > 0
}

export function recordStringMap2(
  value: Record<string, string> | null | undefined,
): Record<string, string> {
  return recordStringMap(value)
}

function hasAuditShape(a: AuditEntry): boolean {
  return hasStringId(a) && typeof a.created_at === 'string'
}


const RAW_TABLE_GROUPS = new Set(['episodic', 'semantic', 'meta'])

export function normalizeRawTableInfo(raw: unknown): RawTableInfo | null {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null
  const item = raw as Record<string, unknown>
  const name = typeof item.name === 'string' ? item.name : ''
  const group = typeof item.group === 'string' ? item.group : ''
  if (!name || !RAW_TABLE_GROUPS.has(group)) return null
  return {
    name,
    label: typeof item.label === 'string' && item.label ? item.label : name,
    group: group as RawTableGroup,
  }
}

/** Every row is dynamic (arbitrary columns per table) — only the envelope is validated. */
export function normalizeRawTableRows(
  raw: unknown,
  fallbackTable: string,
): RawTableRowsResponse {
  const data = raw && typeof raw === 'object' && !Array.isArray(raw) ? (raw as Record<string, unknown>) : {}
  const columns = Array.isArray(data.columns)
    ? data.columns.filter((c): c is string => typeof c === 'string')
    : []
  const items = Array.isArray(data.items)
    ? data.items.filter(
        (row): row is Record<string, unknown> => Boolean(row) && typeof row === 'object' && !Array.isArray(row),
      )
    : []
  return {
    table: typeof data.table === 'string' && data.table ? data.table : fallbackTable,
    columns,
    items,
    limit: typeof data.limit === 'number' ? data.limit : 0,
    offset: typeof data.offset === 'number' ? data.offset : 0,
  }
}

export function normalizeOverview(data: ExplorerOverview | undefined): ExplorerOverview {
  function recordIntMap(v: unknown): Record<string, number> | undefined {
    if (!v || typeof v !== 'object' || Array.isArray(v)) return undefined
    const out: Record<string, number> = {}
    for (const [k, val] of Object.entries(v as Record<string, unknown>)) {
      out[k] = typeof val === 'number' ? val : 0
    }
    return Object.keys(out).length > 0 ? out : undefined
  }
  return {
    bank_count: typeof data?.bank_count === 'number' ? data.bank_count : 0,
    entity_count: typeof data?.entity_count === 'number' ? data.entity_count : 0,
    memory_unit_count: typeof data?.memory_unit_count === 'number' ? data.memory_unit_count : 0,
    memory_unit_by_network: recordIntMap(data?.memory_unit_by_network),
    mental_model_count: typeof data?.mental_model_count === 'number' ? data.mental_model_count : 0,
  }
}

export function normalizeAgentsSettings(
  data: AgentsSettingsResponse | undefined,
): AgentsSettingsResponse | undefined {
  if (!data) {
    return undefined
  }
  return {
    ...data,
    agents: agentsFromSettings(data),
    subject_write_acl: data.subject_write_acl ?? {},
  }
}

export const listValidators = {
  audit: hasAuditShape,
} as const

function normalizeMemoryEntityRefs(raw: unknown): MemoryEntityRef[] {
  if (!Array.isArray(raw)) return []
  return raw
    .map((item): MemoryEntityRef | null => {
      if (!item || typeof item !== 'object') return null
      const r = item as Record<string, unknown>
      if (typeof r.id !== 'string' || typeof r.name !== 'string') return null
      return { id: r.id, name: r.name }
    })
    .filter((r): r is MemoryEntityRef => r != null)
}

function normalizeMemoryFactItem(raw: unknown): MemoryFactItem | null {
  if (!raw || typeof raw !== 'object') return null
  const r = raw as Record<string, unknown>
  if (typeof r.id !== 'string' || typeof r.text !== 'string' || typeof r.network !== 'string') return null
  return {
    id: r.id,
    text: r.text,
    network: r.network,
    mention_time: typeof r.mention_time === 'string' ? r.mention_time : '',
    entities: normalizeMemoryEntityRefs(r.entities),
  }
}

/** GET /v1/explorer/memory/facts — entity-joined facts, distinct from the raw
 * /raw/memory_unit browser this page otherwise uses for the primary list. */
export function normalizeMemoryFactsPage(raw: unknown): MemoryFactsPage {
  const data = raw && typeof raw === 'object' && !Array.isArray(raw) ? (raw as Record<string, unknown>) : {}
  const items = Array.isArray(data.items)
    ? data.items.map(normalizeMemoryFactItem).filter((i): i is MemoryFactItem => i != null)
    : []
  return {
    bank_available: Boolean(data.bank_available),
    items,
    has_more: Boolean(data.has_more),
    limit: typeof data.limit === 'number' ? data.limit : 0,
    offset: typeof data.offset === 'number' ? data.offset : 0,
  }
}

function normalizeMemoryLinkedUnit(raw: unknown): MemoryLinkedUnit | null {
  if (!raw || typeof raw !== 'object') return null
  const r = raw as Record<string, unknown>
  if (typeof r.id !== 'string' || typeof r.text !== 'string' || typeof r.network !== 'string' || typeof r.link_type !== 'string') {
    return null
  }
  return {
    id: r.id,
    text: r.text,
    network: r.network,
    link_type: r.link_type,
    weight: typeof r.weight === 'number' ? r.weight : 0,
    direction: typeof r.direction === 'string' ? r.direction : '',
  }
}

/** GET /v1/explorer/memory/units/{id}/links — one unit's persisted memory_link
 * edges plus live entity-derived adjacency. */
export function normalizeMemoryUnitLinks(raw: unknown): MemoryUnitLinksResponse | null {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null
  const data = raw as Record<string, unknown>
  if (typeof data.unit_id !== 'string') return null
  return {
    unit_id: data.unit_id,
    unit_text: typeof data.unit_text === 'string' ? data.unit_text : '',
    unit_network: typeof data.unit_network === 'string' ? data.unit_network : '',
    links: Array.isArray(data.links)
      ? data.links.map(normalizeMemoryLinkedUnit).filter((l): l is MemoryLinkedUnit => l != null)
      : [],
  }
}

/* ---------- agent-brain semantic memory ---------- */

function stringOrNull(value: unknown): string | null {
  return typeof value === 'string' ? value : null
}

export function normalizeSemanticMemoryItem(raw: unknown): SemanticMemoryItem | null {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null
  const r = raw as Record<string, unknown>
  if (typeof r.id !== 'string' || typeof r.kind !== 'string' || typeof r.title !== 'string') {
    return null
  }
  const entities = Array.isArray(r.entities)
    ? r.entities
        .map((entity): SemanticEntityRef | null => {
          if (!entity || typeof entity !== 'object') return null
          const e = entity as Record<string, unknown>
          return typeof e.id === 'string' && typeof e.name === 'string'
            ? { id: e.id, name: e.name }
            : null
        })
        .filter((entity): entity is SemanticEntityRef => entity != null)
    : []
  const sources = Array.isArray(r.sources)
    ? r.sources
        .map((source): SemanticSourceRef | null => {
          if (!source || typeof source !== 'object') return null
          const s = source as Record<string, unknown>
          return typeof s.id === 'string' && typeof s.title === 'string'
            ? { id: s.id, title: s.title, available: Boolean(s.available) }
            : null
        })
        .filter((source): source is SemanticSourceRef => source != null)
    : undefined
  return {
    id: r.id,
    kind: r.kind,
    title: r.title,
    content: stringOrNull(r.content),
    updated_at: stringOrNull(r.updated_at),
    created_at: typeof r.created_at === 'string' ? r.created_at : '',
    availability: typeof r.availability === 'string' ? r.availability : 'complete',
    source_status:
      typeof r.source_status === 'string' ? r.source_status : 'not_recorded',
    entities,
    truncated: Boolean(r.truncated),
    ...(sources !== undefined ? { sources } : {}),
  }
}

/** Validates the semantic page contract: schema 1, the requested section and offset, a real limit. */
export function normalizeSemanticMemoryPage(
  raw: unknown,
  section: string,
  offset: number,
): SemanticMemoryPage | null {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null
  const data = raw as Record<string, unknown>
  if (
    data.schema_version !== 1 ||
    data.section !== section ||
    data.offset !== offset ||
    typeof data.limit !== 'number' ||
    data.limit <= 0
  ) {
    return null
  }
  const items = Array.isArray(data.items)
    ? data.items
        .map(normalizeSemanticMemoryItem)
        .filter((item): item is SemanticMemoryItem => item != null)
    : []
  return {
    schema_version: 1,
    section,
    retrieved_at: typeof data.retrieved_at === 'string' ? data.retrieved_at : '',
    bank_available: Boolean(data.bank_available),
    items,
    has_more: Boolean(data.has_more),
    offset,
    limit: data.limit,
  }
}

/**
 * Validates the world-model contract (schema 1). Nodes and edges that are not the expected shape are dropped
 * one by one; an edge whose ends are not both returned nodes is dropped too, so the diagram never draws a line to nothing.
 */
export function normalizeSemanticWorld(raw: unknown): SemanticWorldGraph | null {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null
  const data = raw as Record<string, unknown>
  if (data.schema_version !== 1 || typeof data.limit !== 'number' || data.limit <= 0) return null
  const nodes: WorldNode[] = []
  const known = new Set<string>()
  for (const item of Array.isArray(data.nodes) ? data.nodes : []) {
    if (!item || typeof item !== 'object') continue
    const n = item as Record<string, unknown>
    if (typeof n.id !== 'string' || typeof n.label !== 'string' || known.has(n.id)) continue
    const attributes: Record<string, string> = {}
    if (n.attributes && typeof n.attributes === 'object' && !Array.isArray(n.attributes)) {
      for (const [key, value] of Object.entries(n.attributes as Record<string, unknown>)) {
        if (typeof value === 'string' && value) attributes[key] = value
      }
    }
    known.add(n.id)
    nodes.push({
      id: n.id,
      kind: typeof n.kind === 'string' ? n.kind : 'entity',
      ...(typeof n.subtype === 'string' && n.subtype ? { subtype: n.subtype } : {}),
      label: n.label,
      ...(Object.keys(attributes).length ? { attributes } : {}),
      mention_count: typeof n.mention_count === 'number' ? n.mention_count : 0,
    })
  }
  const edges: WorldEdge[] = []
  for (const item of Array.isArray(data.edges) ? data.edges : []) {
    if (!item || typeof item !== 'object') continue
    const e = item as Record<string, unknown>
    if (typeof e.from !== 'string' || typeof e.to !== 'string' || typeof e.label !== 'string' || !e.label) continue
    if (!known.has(e.from) || !known.has(e.to) || e.from === e.to) continue
    edges.push({
      from: e.from,
      to: e.to,
      type: typeof e.type === 'string' ? e.type : 'relation',
      label: e.label,
      source_count: typeof e.source_count === 'number' ? e.source_count : 0,
    })
  }
  return {
    schema_version: 1,
    retrieved_at: typeof data.retrieved_at === 'string' ? data.retrieved_at : '',
    bank_available: Boolean(data.bank_available),
    nodes,
    edges,
    truncated: Boolean(data.truncated),
    limit: data.limit,
  }
}
