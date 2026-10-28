import { describe, expect, it } from 'vitest'
import { TRACKER_CATALOG, knownBlock, observationsFor, providerLabel, safeLinkUrl, viewBlocks, viewForCatalog } from './tracker'
import type { GoalView, ViewState } from './wire'

const catalog = TRACKER_CATALOG

function view(overrides: Partial<GoalView> = {}): GoalView {
  return {
    id: 'v1',
    subject_kind: 'goal',
    subject_id: 'g1',
    catalog_id: catalog,
    metrics: [{ id: 'm1', label: 'Weight', unit: 'kg', target: 70, source: { provider: 'health', series: 'body_weight' } }],
    pages: [
      { id: 'p1', sections: [{ id: 's1', title: 'Overview', blocks: [
        { id: 'b1', kind: 'series', title: 'Weight', metric: 'm1' },
        { id: 'b2', kind: 'steps', title: 'Steps', source: 'goal_steps' },
      ] }] },
    ],
    version: 1,
    ...overrides,
  }
}

function state(overrides: Partial<ViewState> = {}): ViewState {
  return { goal_id: 'g1', catalog_id: catalog, view: view(), measurements: [], ...overrides }
}

describe('view selection', () => {
  it('returns the view for the requested catalogue', () => {
    expect(viewForCatalog(state(), catalog)?.id).toBe('v1')
  })

  it('never substitutes another catalogue, and treats no view or no blocks as none', () => {
    expect(viewForCatalog(state(), 'another-kit.v1')).toBeNull()
    expect(viewForCatalog(state({ view: null }), catalog)).toBeNull()
    expect(viewForCatalog(state({ view: view({ pages: [] }) }), catalog)).toBeNull()
    expect(viewForCatalog(undefined, catalog)).toBeNull()
  })
})

describe('block support', () => {
  it('shows the known types', () => {
    const v = view()
    expect(viewBlocks(v).every((block) => knownBlock(v, block))).toBe(true)
  })

  it('degrades one unknown block without touching the others', () => {
    const blocks = [{ id: 'x', kind: 'webview', title: 'Mystery' }, { id: 'y', kind: 'steps', title: 'Steps', source: 'goal_steps' }]
    const v = view({ pages: [{ id: 'p1', sections: [{ id: 's1', title: 'Overview', blocks }] }] })
    expect(knownBlock(v, blocks[0])).toBe(false)
    expect(knownBlock(v, blocks[1])).toBe(true)
  })

  it('needs a block that draws a metric to name one the view defines', () => {
    const v = view()
    expect(knownBlock(v, { id: 'z', kind: 'log', title: 'Log', metric: 'ghost' })).toBe(false)
    expect(knownBlock(v, { id: 'z', kind: 'grid', title: 'Days' })).toBe(false)
    expect(knownBlock(v, { id: 'z', kind: 'log', title: 'Log', metric: 'm1' })).toBe(true)
    expect(knownBlock(v, { id: 'z', kind: 'sentence', text: 'Hello' })).toBe(true) // a sentence needs no metric of its own
  })

  it('shows a link block only for a web address', () => {
    const v = view()
    expect(knownBlock(v, { id: 'l', kind: 'link', title: 'Plan', url: 'https://example.com/plan' })).toBe(true)
    expect(knownBlock(v, { id: 'l', kind: 'link', title: 'Plan', url: 'javascript:alert(1)' })).toBe(false)
    expect(knownBlock(v, { id: 'l', kind: 'link', title: 'Plan' })).toBe(false)
  })
})

describe('links and labels', () => {
  it('opens only http and https addresses', () => {
    expect(safeLinkUrl('https://example.com/a?b=1')).toBe('https://example.com/a?b=1')
    expect(safeLinkUrl('http://example.com/')).toBe('http://example.com/')
    for (const bad of ['javascript:alert(1)', 'data:text/html,<b>x</b>', 'file:///etc/passwd', 'not a url', '', null, undefined]) {
      expect(safeLinkUrl(bad as string | null | undefined)).toBeNull()
    }
  })

  it('labels a provider id for display', () => {
    expect(providerLabel('finance')).toBe('Finance')
    expect(providerLabel('body_data')).toBe('Body data')
  })
})

describe('observations', () => {
  it('sorts them and drops deleted ones', () => {
    const measurements = [
      { id: 'b', goal_id: 'g1', metric_id: 'm1', value: 2, measured_at: '2026-01-02T00:00:00Z', version: 1 },
      { id: 'a', goal_id: 'g1', metric_id: 'm1', value: 1, measured_at: '2026-01-01T00:00:00Z', version: 1 },
      { id: 'c', goal_id: 'g1', metric_id: 'm1', value: 3, measured_at: '2026-01-03T00:00:00Z', version: 1, deleted_at: '2026-01-04T00:00:00Z' },
      { id: 'd', goal_id: 'g1', metric_id: 'other', value: 9, measured_at: '2026-01-05T00:00:00Z', version: 1 },
    ]
    expect(observationsFor(state({ measurements }), 'm1').map((item) => item.id)).toEqual(['a', 'b'])
  })
})
