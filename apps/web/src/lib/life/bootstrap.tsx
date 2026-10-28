import { useEffect, useRef } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { life } from './operations'
import { newIdempotencyKey } from './client'
import { useLifeSettings } from './hooks'
import { resolvedTimeZone, timeZoneMatches } from './time'
import { lifeKeys } from './queryKeys'

/**
 * Life housekeeping: match the browser timezone once per session and refresh
 * Life queries when the tab becomes active again. Failures stay quiet — a
 * tenant without Life Engine simply has no Life surfaces.
 */
export default function LifeBootstrap() {
  const qc = useQueryClient()
  const settings = useLifeSettings()
  const attempted = useRef(false)

  useEffect(() => {
    if (!settings.data || attempted.current) return
    attempted.current = true
    const zone = resolvedTimeZone()
    if (timeZoneMatches(settings.data.time_zone, zone)) return
    void life
      .settingsSet({
        idempotency_key: newIdempotencyKey(),
        expected_version: settings.data.version,
        time_zone: zone,
        work_start: settings.data.work_start,
        work_end: settings.data.work_end,
      })
      .then(() => qc.invalidateQueries({ queryKey: lifeKeys.settings() }))
      .catch(() => {
        /* keep the server's timezone; it is still the source of truth */
      })
  }, [settings.data, qc])

  useEffect(() => {
    const refresh = () => {
      void qc.invalidateQueries({ queryKey: lifeKeys.all })
    }
    const onVisibility = () => {
      if (document.visibilityState === 'visible') refresh()
    }
    window.addEventListener('focus', refresh)
    document.addEventListener('visibilitychange', onVisibility)
    return () => {
      window.removeEventListener('focus', refresh)
      document.removeEventListener('visibilitychange', onVisibility)
    }
  }, [qc])

  return null
}
