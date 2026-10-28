import { useEffect, useState } from 'react'
import { pickBestReverseGeocodeResult } from '../utils/reverseGeocode'
import { reverseGeocodeLatLng } from '../utils/reverseGeocodeRequest'

const cache = new Map<string, string>()

function llKey(lat: number, lng: number): string {
  return `${lat.toFixed(6)},${lng.toFixed(6)}`
}

function coordFallback(lat: number, lng: number): string {
  return `${lat.toFixed(4)}, ${lng.toFixed(4)}`
}

/**
 * Reverse-geocodes a point for trip cards (cached). Shows "…" until resolved.
 */
export function useTripEndpointLabel(lat: number, lng: number): string {
  const key = llKey(lat, lng)
  // Resolved labels, by point. Written only from the async callback below, so no state is set in the effect body.
  const [resolved, setResolved] = useState<Record<string, string>>({})

  useEffect(() => {
    if (cache.has(key)) return
    let cancelled = false
    ;(async () => {
      let name = coordFallback(lat, lng)
      try {
        const { results, status } = await reverseGeocodeLatLng(lat, lng)
        if (status === 'OK' && results.length) {
          const r = pickBestReverseGeocodeResult(results, lat, lng)
          if (r?.formatted_address) name = r.formatted_address
        }
      } catch {
        /* keep the coordinates */
      }
      cache.set(key, name)
      if (!cancelled) setResolved((p) => ({ ...p, [key]: name }))
    })()
    return () => {
      cancelled = true
    }
  }, [key, lat, lng])

  return cache.get(key) ?? resolved[key] ?? '…'
}
