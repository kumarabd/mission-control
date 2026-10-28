import type { GoalView, Measurement, ViewBlock, ViewState } from './wire'

/** The view kit this client draws. One manifest per goal serves every client; each draws it with its own components. */
export const TRACKER_CATALOG = 'view-kit.v1'

/** The view a state holds for the catalogue asked for, or null: another app's view is never substituted. */
export function viewForCatalog(state: ViewState | undefined, catalog: string): GoalView | null {
  const view = state?.view
  if (!view || view.catalog_id !== catalog || viewBlocks(view).length === 0) return null
  return view
}

/** Every block of a view in display order, whatever page and section it is on. */
export function viewBlocks(view: GoalView): ViewBlock[] {
  return view.pages.flatMap((page) => page.sections.flatMap((section) => section.blocks))
}

const KNOWN_BLOCKS = new Set(['sentence', 'bar', 'series', 'grid', 'steps', 'timeline', 'tasks', 'events', 'log', 'text', 'link'])

/**
 * Whether this client can show a block. An unknown kind, or a block naming a metric the view does not define, is shown
 * as unsupported on its own; it never hides the rest of the view.
 */
export function knownBlock(view: GoalView, block: ViewBlock): boolean {
  if (!KNOWN_BLOCKS.has(block.kind)) return false
  if (block.kind === 'series' || block.kind === 'grid' || block.kind === 'log') {
    return view.metrics.some((metric) => metric.id === block.metric)
  }
  if (block.kind === 'link') return safeLinkUrl(block.url) !== null
  return true
}

/** Only http and https addresses are opened; anything else a stored view carries is ignored. */
export function safeLinkUrl(url: string | null | undefined): string | null {
  if (!url) return null
  try {
    const parsed = new URL(url)
    return parsed.protocol === 'https:' || parsed.protocol === 'http:' ? parsed.toString() : null
  } catch {
    return null
  }
}

/** `finance` -> `Finance`; a provider id is a router prefix, so this is only for display. */
export function providerLabel(provider: string): string {
  return provider.charAt(0).toUpperCase() + provider.slice(1).replace(/_/g, ' ')
}

export function observationsFor(state: ViewState | undefined, metricId: string): Measurement[] {
  if (!state) return []
  return state.measurements
    .filter((measurement) => measurement.metric_id === metricId && !measurement.deleted_at)
    .sort((a, b) => new Date(a.measured_at).getTime() - new Date(b.measured_at).getTime())
}
