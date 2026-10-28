import { ArrowLeft } from 'lucide-react'
import { useEffect, useMemo } from 'react'
import { Link, useParams } from 'react-router-dom'
import { EmptyState, SkeletonRows, Stat } from '../../components/ui'
import { cn } from '../../lib/cn'
import { useDriveRoute, useDrives, useDriveSensors, useDriveSeries, useGarage } from '../hooks/useDrives'
import { SPEED_SERIES, useDriveStore } from '../stores/driveStore'
import { formatDriveTime, formatMiles, formatMph, formatReading, groupSensors, kmToMiles, vehicleName } from '../utils/drives'
import { SensorChart } from './charts'

/** One drive in full: its numbers, a chart of any sensor it recorded, and everything it captured. */
export default function DrivePanel() {
  const { id = '' } = useParams()
  const drives = useDrives()
  const garage = useGarage()
  const drive = drives.data?.find((d) => d.id === id)
  const pid = useDriveStore((s) => s.selectedPid)
  const selectPid = useDriveStore((s) => s.selectPid)
  const resetPid = useDriveStore((s) => s.resetPid)
  const route = useDriveRoute(id)
  const sensors = useDriveSensors(id)
  const isSpeed = pid === SPEED_SERIES
  const series = useDriveSeries(id, isSpeed ? null : pid)
  useEffect(() => resetPid(), [id, resetPid])

  const groups = useMemo(() => groupSensors(sensors.data ?? []), [sensors.data])
  const sensor = (sensors.data ?? []).find((s) => s.pid === pid)

  if (drives.isLoading) return <SkeletonRows count={5} />
  if (!drive) {
    return <EmptyState icon={undefined} title="This trip isn't here" body="It may be older than the recent list, or from another account." action={{ label: 'Back to Trips', to: '/travel/trips' }} />
  }

  const vehicle = vehicleName((garage.data ?? []).find((v) => v.id === drive.vehicle_id), drive.vehicle_id)
  const start = new Date(drive.started_at)
  const chart = isSpeed
    ? { title: 'Speed', unit: 'mph', points: (route.data ?? []).map((p) => ({ time: p.time, value: kmToMiles(p.speed_kmh) })), loading: route.isLoading }
    : { title: sensor?.label || pid, unit: sensor?.unit ?? '', points: series.data ?? [], loading: series.isLoading }

  return (
    <div className="mx-auto w-full max-w-2xl space-y-6">
      <div className="space-y-3">
        <Link to="/travel/trips" className="inline-flex items-center gap-1.5 text-sm text-flat-muted-fg no-underline hover:text-flat-foreground hover:no-underline">
          <ArrowLeft className="size-3.5" aria-hidden />
          Trips
        </Link>
        <div>
          <h1 className="text-xl text-flat-foreground md:text-2xl">
            {start.toLocaleDateString('en-US', { weekday: 'long', month: 'short', day: 'numeric' })}
          </h1>
          <p className="text-base text-flat-muted-fg">
            {start.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })} · {vehicle}
            {drive.status === 'ACTIVE' ? ' · recording now' : drive.status === 'INTERRUPTED' ? ' · ended unexpectedly' : ''}
          </p>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">
        <Stat label="Distance" value={formatMiles(drive.distance_km)} />
        <Stat label="Time" value={formatDriveTime(drive.duration_sec)} />
        <Stat label="Average" value={formatMph(drive.avg_speed_kmh)} />
        <Stat label="Top speed" value={formatMph(drive.max_speed_kmh)} />
        <Stat label="Readings" value={drive.observations.toLocaleString('en-US')} />
        <Stat label="Sensors" value={sensors.data ? sensors.data.length : '—'} />
      </div>

      <SensorChart {...chart} />

      <section aria-labelledby="captured">
        <h2 id="captured" className="text-base font-medium text-flat-foreground">
          Everything captured
        </h2>
        <p className="mb-3 text-sm text-flat-muted-fg">Choose a reading to chart it.</p>
        {sensors.isLoading && <SkeletonRows count={4} />}
        {sensors.isError && <p className="text-sm text-flat-danger">Couldn't load the readings.</p>}
        {groups.map((g) => (
          <div key={g.title} className="mb-4">
            <h3 className="mb-1 text-sm font-medium text-flat-muted-fg">{g.title}</h3>
            <ul className="divide-y divide-flat-border rounded-md border border-flat-border">
              {g.sensors.map((s) => {
                const on = s.pid === pid
                return (
                  <li key={s.pid}>
                    <button
                      type="button"
                      aria-pressed={on}
                      onClick={() => selectPid(s.pid)}
                      className={cn('flex w-full items-center justify-between gap-3 px-3 py-2 text-left text-base transition-colors', on ? 'bg-flat-tint' : 'hover:bg-flat-muted')}
                    >
                      <span className="min-w-0 truncate text-flat-foreground">{s.label || s.pid}</span>
                      <span className="shrink-0 text-sm tabular-nums text-flat-muted-fg">
                        {s.min === s.max ? formatReading(s.min, s.label) : `${formatReading(s.min, s.label)} – ${formatReading(s.max, s.label)}`}
                        {s.unit ? ` ${s.unit}` : ''}
                      </span>
                    </button>
                  </li>
                )
              })}
            </ul>
          </div>
        ))}
        {sensors.data && sensors.data.length === 0 && <p className="text-sm text-flat-muted-fg">This trip recorded no sensor readings.</p>}
      </section>
    </div>
  )
}
