import { useQuery } from '@tanstack/react-query'
import { ArrowRight, Route as RouteIcon } from 'lucide-react'
import { useMemo, type CSSProperties } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { Badge, EmptyState, PageHeader, Segmented, SkeletonRows, Stat } from '../../components/ui'
import { cn } from '../../lib/cn'
import { getTrips } from '../api/fleet'
import type { Drive } from '../api/journeys'
import type { Trip } from '../api/types'
import { useDriveStats, useDrives, useGarage } from '../hooks/useDrives'
import { useTripEndpointLabel } from '../hooks/useTripEndpointLabel'
import { useDriveStore, type DaysWindow } from '../stores/driveStore'
import { newRouteStopRow, useRouteStore } from '../stores/routeStore'
import { formatDriveTime, formatMiles, formatMph, vehicleName } from '../utils/drives'
import { describeError } from '../utils/errors'
import { formatCurrency, formatDistance, formatDuration } from '../utils/format'
import { mergeTrips, type TripFilter } from '../utils/trips'
import { DistanceBars } from './charts'

const WINDOWS: { value: `${DaysWindow}`; label: string }[] = [
  { value: '7', label: '7 days' },
  { value: '30', label: '30 days' },
  { value: '90', label: '90 days' },
]
const FILTERS: { value: TripFilter; label: string }[] = [
  { value: 'all', label: 'All' },
  { value: 'driven', label: 'Driven' },
  { value: 'planned', label: 'Planned' },
]

const rowCls = (i: number): { className: string; style: CSSProperties } => ({
  className:
    'external-system-card block w-full rounded-md border border-flat-border bg-flat-surface p-3 text-left no-underline transition-colors hover:border-flat-border-strong hover:no-underline',
  style: { '--connection-card-delay': `${Math.min(i, 8) * 40}ms` } as CSSProperties,
})

function DriveRow({ drive, vehicle, index }: { drive: Drive; vehicle: string; index: number }) {
  const start = new Date(drive.started_at)
  const when = `${start.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' })} · ${start.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })}`
  const { className, style } = rowCls(index)
  return (
    <li>
      <Link to={`/travel/trips/${drive.id}`} className={className} style={style}>
        <span className="flex items-start justify-between gap-3">
          <span className="min-w-0">
            <span className="flex items-center gap-2">
              <Badge tone="success">Driven</Badge>
              <span className="truncate text-base font-medium text-flat-foreground">{when}</span>
            </span>
            <span className="mt-0.5 block truncate text-sm text-flat-muted-fg">
              {vehicle}
              {drive.status === 'ACTIVE' ? ' · recording now' : drive.status === 'INTERRUPTED' ? ' · ended unexpectedly' : ''}
            </span>
          </span>
          <span className="shrink-0 text-right tabular-nums">
            <span className="block text-base font-medium text-flat-foreground">{formatMiles(drive.distance_km)}</span>
            <span className="block text-sm text-flat-muted-fg">
              {formatDriveTime(drive.duration_sec)} · top {formatMph(drive.max_speed_kmh)}
            </span>
          </span>
        </span>
      </Link>
    </li>
  )
}

function PlannedRow({ trip, index }: { trip: Trip; index: number }) {
  const navigate = useNavigate()
  const setRouteStops = useRouteStore((s) => s.setRouteStops)
  const clearPlanOnly = useRouteStore((s) => s.clearPlanOnly)
  const from = useTripEndpointLabel(trip.origin.lat, trip.origin.lng)
  const to = useTripEndpointLabel(trip.destination.lat, trip.destination.lng)
  const label = (l: string, p: { lat: number; lng: number }) => (l !== '…' ? l : `${p.lat.toFixed(4)}, ${p.lng.toFixed(4)}`)
  const { className, style } = rowCls(index)

  const reuse = () => {
    setRouteStops([
      newRouteStopRow({ name: label(from, trip.origin), ...trip.origin }),
      newRouteStopRow({ name: label(to, trip.destination), ...trip.destination }),
    ])
    clearPlanOnly()
    navigate('/travel/plan')
  }
  return (
    <li>
      <button type="button" onClick={reuse} className={className} style={style}>
        <span className="flex items-center gap-2 text-sm text-flat-muted-fg">
          <Badge tone="accent">Planned</Badge>
          {new Date(trip.createdAt).toLocaleString('en-US', { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' })}
        </span>
        <span className="mt-1 flex items-center gap-1.5 text-base font-medium text-flat-foreground">
          <span className="line-clamp-1">{from}</span>
          <ArrowRight className="size-3.5 shrink-0 text-flat-subtle-fg" aria-hidden />
          <span className="line-clamp-1">{to}</span>
        </span>
        <span className="mt-1 flex gap-3 text-sm tabular-nums text-flat-muted-fg">
          <span>{formatDistance(trip.totalDistanceMeters)}</span>
          <span>{formatDuration(trip.totalDurationSeconds)}</span>
          <span>{formatCurrency(trip.totalCostDollars)}</span>
          <span className="ml-auto text-flat-primary">Plan again</span>
        </span>
      </button>
    </li>
  )
}

export default function TripsPanel() {
  const { days, setDays, filter, setFilter } = useDriveStore()
  const drives = useDrives()
  const planned = useQuery({ queryKey: ['trips'], queryFn: getTrips })
  const stats = useDriveStats(days)
  const garage = useGarage()

  const names = useMemo(() => {
    const byId = new Map((garage.data ?? []).map((v) => [v.id, v]))
    return (id: string) => vehicleName(byId.get(id), id)
  }, [garage.data])

  const items = mergeTrips(drives.data ?? [], planned.data ?? [], filter)
  const loading = drives.isLoading || planned.isLoading
  const failed = drives.isError || planned.isError
  const st = stats.data

  return (
    <div className="mx-auto w-full max-w-2xl space-y-6">
      <PageHeader
        title="Trips"
        description="What you drove, recorded by your phone, and the routes you planned."
        actions={<Segmented size="sm" value={`${days}` as `${DaysWindow}`} onValueChange={(v) => setDays(Number(v) as DaysWindow)} options={WINDOWS} />}
      />

      {filter !== 'planned' && (
        <section aria-label={`Totals for the last ${days} days`} className="space-y-4">
          {stats.isError && <p className="text-sm text-flat-danger">{describeError(stats.error, 'totals')}</p>}
          {st && (
            <>
              <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">
                <Stat label="Trips" value={st.journeys} />
                <Stat label="Distance" value={formatMiles(st.distance_km)} />
                <Stat label="Driving" value={formatDriveTime(st.duration_sec)} />
              </div>
              <DistanceBars days={st.by_day} />
              {st.by_vehicle.length > 1 && (
                <ul className="space-y-1 text-base">
                  {st.by_vehicle.map((v) => (
                    <li key={v.vehicle_id} className="flex justify-between gap-3 text-flat-muted-fg">
                      <span className="truncate">{names(v.vehicle_id)}</span>
                      <span className="shrink-0 tabular-nums text-flat-foreground">
                        {formatMiles(v.distance_km)} · {v.journeys} {v.journeys === 1 ? 'trip' : 'trips'}
                      </span>
                    </li>
                  ))}
                </ul>
              )}
            </>
          )}
        </section>
      )}

      <section aria-label="Trips" className="space-y-3">
        <Segmented size="sm" value={filter} onValueChange={setFilter} options={FILTERS} />
        {loading && <SkeletonRows count={4} />}
        {failed && <p className="text-sm text-flat-danger">{describeError(drives.error ?? planned.error, 'trips')}</p>}
        {!loading && !failed && items.length === 0 && (
          <EmptyState
            size="sm"
            icon={<RouteIcon />}
            title={filter === 'planned' ? 'No planned trips yet' : 'No trips yet'}
            body={filter === 'planned' ? 'Plan a route and it shows up here.' : 'Plan a route, or start a drive in the app and it appears here as it streams.'}
            action={{ label: 'Plan a trip', to: '/travel/plan' }}
          />
        )}
        {items.length > 0 && (
          <ul className={cn('space-y-2')}>
            {items.map((i, n) =>
              i.kind === 'driven' ? (
                <DriveRow key={`d-${i.drive.id}`} drive={i.drive} vehicle={names(i.drive.vehicle_id)} index={n} />
              ) : (
                <PlannedRow key={`p-${i.trip.id}`} trip={i.trip} index={n} />
              ),
            )}
          </ul>
        )}
      </section>
    </div>
  )
}
