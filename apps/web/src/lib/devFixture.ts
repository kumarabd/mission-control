const KEY = 'mission-control-fixture'

/**
 * DEV-only visual QA mode. Enabled by opening any authenticated page with
 * `?fixture=1`; the choice sticks for the tab so navigation keeps working.
 * Production builds compile the check away, and no fixture module is imported.
 */
export function fixtureEnabled(): boolean {
  if (!import.meta.env.DEV) return false
  try {
    const fixture = new URLSearchParams(window.location.search).get('fixture')
    if (fixture === '1') sessionStorage.setItem(KEY, '1')
    if (fixture === '0') sessionStorage.removeItem(KEY)
    return sessionStorage.getItem(KEY) === '1'
  } catch {
    return false
  }
}
