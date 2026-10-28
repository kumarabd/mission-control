import {
  AdvancedMarker,
  AdvancedMarkerAnchorPoint,
  InfoWindow,
  Polyline,
  useAdvancedMarkerRef,
  useMap,
} from '@vis.gl/react-google-maps'
import { Fuel, Zap } from 'lucide-react'
import { useCallback, useEffect, useMemo, useState } from 'react'
import { useMapFitOriginDest, useMapFitToRoute, useMapPanToSoloOrigin } from '../hooks/useMapFit'
import { useRouteStore } from '../stores/routeStore'
import { useMapStore } from '../stores/mapStore'
import { decodePolyline } from '../utils/polyline'
import { pickBestReverseGeocodeResult } from '../utils/reverseGeocode'
import { reverseGeocodeLatLng } from '../utils/reverseGeocodeRequest'
import { ROUTE_DRAW_MS, useSignalColor } from './signal'
import type { RoutePlanStop } from '../api/contract/routePlan'
import { cn } from '../../lib/cn'

export function MapBindings() {
  const map = useMap()
  const setMapInstance = useMapStore((s) => s.setMapInstance)
  useEffect(() => {
    if (map) setMapInstance(map)
    return () => setMapInstance(null)
  }, [map, setMapInstance])
  useMapFitToRoute()
  useMapFitOriginDest()
  useMapPanToSoloOrigin()
  return null
}

/** Round, token-coloured pin with a label — the same A, B, C the stop list shows. */
function Pin({ label, tone }: { label: string; tone: 'origin' | 'via' | 'dest' | 'pick' }) {
  return (
    <div
      className={cn(
        'flex size-6 items-center justify-center border-2 border-flat-background text-2xs font-semibold shadow-2',
        tone === 'origin' && 'rounded-full bg-flat-foreground text-flat-background',
        tone === 'dest' && 'rounded-[5px] bg-flat-foreground text-flat-background',
        tone === 'via' && 'rounded-full bg-flat-warning text-flat-background',
        tone === 'pick' && 'rounded-full bg-flat-primary text-flat-on-primary',
      )}
    >
      {label}
    </div>
  )
}

export function RouteStopsMarkers() {
  const routeStops = useRouteStore((s) => s.routeStops)
  return (
    <>
      {routeStops.map((row, index) => {
        const p = row.place
        if (!p || row.fromPlan) return null
        const tone = index === 0 ? 'origin' : index === routeStops.length - 1 ? 'dest' : 'via'
        const label = String.fromCharCode(65 + index)
        return (
          <AdvancedMarker key={row.id} position={{ lat: p.lat, lng: p.lng }} title={`${label} · ${p.name}`}>
            <Pin label={label} tone={tone} />
          </AdvancedMarker>
        )
      })}
    </>
  )
}

export function ChargerMarker({
  stop,
  index,
  selected,
  onSelect,
}: {
  stop: RoutePlanStop
  index: number
  selected: boolean
  onSelect: () => void
}) {
  const fuel = stop.stopType.toLowerCase() === 'fuel' || stop.ice != null
  const Icon = fuel ? Fuel : Zap
  return (
    <AdvancedMarker
      position={stop.location}
      title={`${stop.name} — ${Math.round(stop.stopDurationMin)} min`}
      onClick={onSelect}
      zIndex={selected ? 100 + index : 10 + index}
      anchorPoint={AdvancedMarkerAnchorPoint.CENTER}
    >
      <div
        className={cn(
          'flex items-center justify-center rounded-full border-2 border-flat-background bg-flat-primary text-flat-on-primary shadow-2 transition-transform duration-[var(--duration-fast)] ease-[var(--ease-standard)]',
          selected ? 'size-8 scale-110' : 'size-6',
        )}
      >
        <Icon className="size-3.5" aria-hidden />
      </div>
    </AdvancedMarker>
  )
}

/**
 * The planned route, drawn from start to end. The reveal is the one authored moment of the plan screen: the stop list's
 * spine draws down in step with it (see .travel-spine in index.css, same duration and easing).
 */
const easeOutExpo = (t: number) => (t >= 1 ? 1 : 1 - Math.pow(2, -10 * t))

export function RoutePolyline() {
  const plan = useRouteStore((s) => s.plan)
  const { line } = useSignalColor()
  const encoded = plan?.route.polyline ?? ''
  const full = useMemo(() => (encoded ? decodePolyline(encoded) : []), [encoded])
  const reduced = useMemo(() => window.matchMedia('(prefers-reduced-motion: reduce)').matches, [])
  // How far the draw has got, for which route. A new route starts again from zero without any reset in an effect.
  const [drawn, setDrawn] = useState({ route: '', k: 0 })

  useEffect(() => {
    if (full.length === 0 || reduced) return
    let raf = 0
    const t0 = performance.now()
    const tick = (now: number) => {
      const k = easeOutExpo((now - t0) / ROUTE_DRAW_MS)
      setDrawn({ route: encoded, k })
      if (k < 1) raf = requestAnimationFrame(tick)
    }
    raf = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(raf)
  }, [encoded, full.length, reduced])

  if (!plan || full.length === 0) return null
  const visible = reduced ? full.length : drawn.route === encoded ? Math.ceil(drawn.k * full.length) : 0
  const path = full.slice(0, Math.max(visible, 2))
  return (
    <>
      <Polyline path={path} strokeColor={line} strokeOpacity={0.25} strokeWeight={10} geodesic />
      <Polyline path={path} strokeColor={line} strokeOpacity={1} strokeWeight={4} geodesic />
    </>
  )
}

/** A map tap on the plan screen stages a pick (reverse-geocoded); "Add stop" in its card puts it on the route. */
export function MapRouteClickHandler() {
  const map = useMap()
  const setMapPickPreview = useRouteStore((s) => s.setMapPickPreview)
  const setMapPickGeocoding = useRouteStore((s) => s.setMapPickGeocoding)

  const onMapClick = useCallback(
    async (e: google.maps.MapMouseEvent) => {
      e.stop() // no Google POI card; ours has the route actions
      const ll = e.latLng
      if (!ll) return
      const lat = ll.lat()
      const lng = ll.lng()
      const coords = `${lat.toFixed(5)}, ${lng.toFixed(5)}`
      setMapPickPreview({ name: coords, lat, lng })
      setMapPickGeocoding(true)
      let name = coords
      try {
        const { results, status } = await reverseGeocodeLatLng(lat, lng)
        if (status === 'OK' && results.length) {
          const r = pickBestReverseGeocodeResult(results, lat, lng)
          if (r?.formatted_address) name = r.formatted_address
        }
      } catch {
        /* keep the coordinates */
      }
      // A newer tap replaced this one while we looked up the address.
      if (useRouteStore.getState().mapPickPreview?.lat !== lat) return
      setMapPickPreview({ name, lat, lng })
      setMapPickGeocoding(false)
    },
    [setMapPickGeocoding, setMapPickPreview],
  )

  useEffect(() => {
    if (!map) return
    const l = map.addListener('click', onMapClick)
    return () => l.remove()
  }, [map, onMapClick])
  return null
}

export function MapPickPreviewMarker() {
  const preview = useRouteStore((s) => s.mapPickPreview)
  const geocoding = useRouteStore((s) => s.mapPickGeocoding)
  const commit = useRouteStore((s) => s.commitMapPickToRoute)
  const clear = useRouteStore((s) => s.clearMapPickPreview)
  const [setRef, marker] = useAdvancedMarkerRef()
  if (!preview) return null
  return (
    <>
      <AdvancedMarker ref={setRef} position={{ lat: preview.lat, lng: preview.lng }} title={preview.name}>
        <Pin label={geocoding ? '…' : '+'} tone="pick" />
      </AdvancedMarker>
      {marker && (
        <InfoWindow anchor={marker} onCloseClick={clear} headerContent={<span className="text-sm font-semibold">Map pick</span>}>
          <div className="max-w-[260px] p-1 text-slate-800">
            <p className="text-xs leading-snug">{geocoding ? 'Looking up the address…' : preview.name}</p>
            <div className="mt-2 flex gap-2">
              <button
                type="button"
                disabled={geocoding}
                onClick={commit}
                className="rounded-md bg-[#1f5eff] px-3 py-1.5 text-xs font-medium text-white disabled:opacity-50"
              >
                Add stop
              </button>
              <button type="button" onClick={clear} className="rounded-md border border-slate-300 px-3 py-1.5 text-xs font-medium">
                Cancel
              </button>
            </div>
          </div>
        </InfoWindow>
      )}
    </>
  )
}
