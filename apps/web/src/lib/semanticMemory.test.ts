import { describe, expect, it } from 'vitest'
import { normalizeSemanticMemoryItem, normalizeSemanticMemoryPage, normalizeSemanticWorld } from './safe'

const item = {
  id: 'item-1',
  kind: 'mental_model',
  title: 'You do your best work in the morning',
  content: 'A reflection.',
  created_at: '2026-01-01T00:00:00Z',
  updated_at: '2026-01-02T00:00:00Z',
  availability: 'complete',
  source_status: 'recorded',
  truncated: false,
  entities: [{ id: 'e1', name: 'Morning routine' }],
  sources: [{ id: 's1', title: 'A morning note', available: true }],
}

const page = {
  schema_version: 1,
  section: 'reflections',
  retrieved_at: '2026-01-03T00:00:00Z',
  bank_available: true,
  items: [item],
  has_more: false,
  offset: 0,
  limit: 20,
}

describe('semantic memory validation', () => {
  it('accepts the schema-1 page contract', () => {
    const normalized = normalizeSemanticMemoryPage(page, 'reflections', 0)
    expect(normalized?.items).toHaveLength(1)
    expect(normalized?.items[0]).toMatchObject({
      id: 'item-1',
      kind: 'mental_model',
      source_status: 'recorded',
      entities: [{ id: 'e1', name: 'Morning routine' }],
    })
  })

  it('rejects a different schema, section or offset', () => {
    expect(normalizeSemanticMemoryPage({ ...page, schema_version: 2 }, 'reflections', 0)).toBeNull()
    expect(normalizeSemanticMemoryPage(page, 'about_you', 0)).toBeNull()
    expect(normalizeSemanticMemoryPage({ ...page, offset: 1 }, 'reflections', 0)).toBeNull()
    expect(normalizeSemanticMemoryPage({ ...page, limit: 0 }, 'reflections', 0)).toBeNull()
  })

  it('accepts a server-clamped page size', () => {
    const normalized = normalizeSemanticMemoryPage(
      { ...page, limit: 10 },
      'reflections',
      0,
    )
    expect(normalized?.limit).toBe(10)
  })

  it('drops malformed items instead of failing the page', () => {
    const normalized = normalizeSemanticMemoryPage(
      { ...page, items: [item, { id: 3 }, null] },
      'reflections',
      0,
    )
    expect(normalized?.items).toHaveLength(1)
  })

  it('normalizes a single semantic item', () => {
    expect(normalizeSemanticMemoryItem(item)).toMatchObject({
      id: 'item-1',
      sources: [{ id: 's1', title: 'A morning note', available: true }],
    })
    expect(normalizeSemanticMemoryItem({ ...item, id: undefined })).toBeNull()
  })
})

describe('world model validation', () => {
  const world = {
    schema_version: 1,
    retrieved_at: '2026-10-25T10:00:00Z',
    bank_available: true,
    truncated: false,
    limit: 100,
    nodes: [
      { id: 'entity:a', kind: 'entity', subtype: 'person', label: 'Dana', attributes: { role: 'lead', empty: '', n: 3 }, mention_count: 9 },
      { id: 'entity:b', kind: 'entity', label: 'Acme', mention_count: 4 },
      { id: 'entity:a', kind: 'entity', label: 'Duplicate id', mention_count: 1 },
      { kind: 'entity', label: 'No id' },
      'not an object',
    ],
    edges: [
      { from: 'entity:a', to: 'entity:b', type: 'relation', label: 'works_at', source_count: 2 },
      { from: 'entity:a', to: 'entity:zzz', type: 'relation', label: 'knows', source_count: 1 },
      { from: 'entity:a', to: 'entity:a', type: 'relation', label: 'is', source_count: 1 },
      { from: 'entity:b', to: 'entity:a', label: '' },
    ],
  }

  it('accepts the schema-1 contract and keeps the free-form fields as sent', () => {
    const normalized = normalizeSemanticWorld(world)
    expect(normalized?.nodes.map((n) => n.id)).toEqual(['entity:a', 'entity:b'])
    expect(normalized?.nodes[0]).toMatchObject({ subtype: 'person', attributes: { role: 'lead' } })
    expect(normalized?.nodes[1].subtype).toBeUndefined()
    expect(normalized?.nodes[1].attributes).toBeUndefined()
  })

  it('drops edges that do not join two returned nodes, or join a node to itself', () => {
    expect(normalizeSemanticWorld(world)?.edges).toEqual([
      { from: 'entity:a', to: 'entity:b', type: 'relation', label: 'works_at', source_count: 2 },
    ])
  })

  it('rejects an unknown schema or a missing limit', () => {
    expect(normalizeSemanticWorld({ ...world, schema_version: 2 })).toBeNull()
    expect(normalizeSemanticWorld({ ...world, limit: 0 })).toBeNull()
    expect(normalizeSemanticWorld(null)).toBeNull()
    expect(normalizeSemanticWorld([])).toBeNull()
  })
})
