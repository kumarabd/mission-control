import type { SemanticMemoryItem } from './types'

/**
 * Detail routes are shareable, but the semantic API has no item-by-id read.
 * Keep the last list payload for this tab so a reload or deep link can still
 * show the item without inventing data.
 */
export function cacheSemanticItem(item: SemanticMemoryItem): void {
  try {
    sessionStorage.setItem(`semantic-item:${item.id}`, JSON.stringify(item))
  } catch {
    /* a blocked store only affects direct reloads */
  }
}

export function readCachedSemanticItem(id: string): SemanticMemoryItem | null {
  try {
    const raw = sessionStorage.getItem(`semantic-item:${id}`)
    if (!raw) return null
    const parsed = JSON.parse(raw) as SemanticMemoryItem
    return parsed && parsed.id === id && typeof parsed.title === 'string' ? parsed : null
  } catch {
    return null
  }
}
