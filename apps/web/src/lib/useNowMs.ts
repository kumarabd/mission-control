import { useEffect, useSyncExternalStore } from 'react'

const REFRESH_MS = 15_000

let nowMs = 0
const listeners = new Set<() => void>()

function subscribe(onStoreChange: () => void) {
  listeners.add(onStoreChange)
  return () => listeners.delete(onStoreChange)
}

function getSnapshot() {
  return nowMs
}

function getServerSnapshot() {
  return 0
}

function publishNow() {
  nowMs = Date.now()
  listeners.forEach((listener) => listener())
}

/** Start ticker once when the module is first used in the browser. */
function ensureTicker() {
  if (typeof window === 'undefined') return
  if ((ensureTicker as { started?: boolean }).started) return
  ;(ensureTicker as { started?: boolean }).started = true
  publishNow()
  window.setInterval(publishNow, REFRESH_MS)
}

/**
 * Current time (ms) for overdue checks. Updates on an interval and when
 * refreshKey changes (e.g. React Query dataUpdatedAt) without Date.now() in render.
 */
export function useNowMs(refreshKey?: number | string) {
  ensureTicker()

  useEffect(() => {
    publishNow()
  }, [refreshKey])

  return useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot)
}
