import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Car, Plus } from 'lucide-react'
import { useState, type CSSProperties } from 'react'
import { Link } from 'react-router-dom'
import { Button, Card, EmptyState, Field, Input, PageHeader, SkeletonRows } from '../../components/ui'
import { cn } from '../../lib/cn'
import { ApiError } from '../api/client'
import { getUserMe, setActiveVehicleVin } from '../api/fleet'
import type { VehicleStatus } from '../api/types'
import { getFleetStatus, initialVehicleStateAfterOnboard, onboardVehicleFromVin, putVehicleState } from '../api/vehicles'
import { describeError } from '../utils/errors'
import { formatRelative } from '../../lib/format'

const STATUS_LABEL = { online: 'Online', charging: 'Charging', offline: 'Offline' } as const

/** Charge or fuel as 20 small segments, so a low level reads at a glance without a number. */
export function EnergyGauge({ percent, label }: { percent: number; label: string }) {
  const pct = Math.max(0, Math.min(100, percent))
  const lit = Math.round(pct / 5)
  const tone = pct < 20 ? 'bg-flat-danger' : pct < 40 ? 'bg-flat-warning' : 'bg-flat-success'
  return (
    <div role="meter" aria-label={label} aria-valuemin={0} aria-valuemax={100} aria-valuenow={Math.round(pct)} className="flex gap-[2px]">
      {Array.from({ length: 20 }, (_, i) => (
        <span key={i} className={cn('h-2 flex-1 rounded-[1px]', i < lit ? tone : 'bg-flat-muted')} />
      ))}
    </div>
  )
}

function VehicleCard({ v, active, index, onSetActive, busy }: { v: VehicleStatus; active: boolean; index: number; onSetActive?: () => void; busy: boolean }) {
  const pct = v.stateOfChargePercent ?? v.fuelPercent
  const kind = v.stateOfChargePercent != null ? 'Charge' : 'Fuel'
  return (
    <Card
      padding="none"
      className="external-system-card overflow-hidden"
      style={{ '--connection-card-delay': `${Math.min(index, 8) * 55}ms` } as CSSProperties}
    >
      <Link to={`/travel/fleet/${encodeURIComponent(v.vin)}`} className="block space-y-3 p-4 no-underline hover:no-underline">
        <div className="flex items-start justify-between gap-3">
          <div className="min-w-0">
            <p className="truncate text-md font-semibold text-flat-foreground">{v.name}</p>
            <p className="truncate font-mono text-xs text-flat-subtle-fg">{v.vin}</p>
          </div>
          <span className="flex shrink-0 items-center text-sm font-medium text-flat-muted-fg">
            <span className={`status-dot status-dot--${v.connectionStatus} mr-1.5`} aria-hidden />
            {STATUS_LABEL[v.connectionStatus]}
          </span>
        </div>
        {pct != null ? (
          <div className="space-y-1.5">
            <div className="flex items-baseline justify-between text-sm">
              <span className="text-flat-muted-fg">{kind}</span>
              <span className="font-mono tabular-nums text-flat-foreground">
                {Math.round(pct)}%
                {v.estimatedRangeKm != null && <span className="ml-2 text-flat-muted-fg">~{Math.round(v.estimatedRangeKm / 1.609344)} mi</span>}
              </span>
            </div>
            <EnergyGauge percent={pct} label={`${kind} level`} />
          </div>
        ) : (
          <p className="text-sm text-flat-muted-fg">No {v.drivetrain === 'ICE' ? 'fuel' : 'charge'} reading yet.</p>
        )}
        <p className="text-xs text-flat-subtle-fg">{v.lastUpdatedAt ? `Updated ${formatRelative(v.lastUpdatedAt)}` : 'Not updated yet'}</p>
      </Link>
      {onSetActive && (
        <div className="flex items-center justify-between border-t border-flat-border px-4 py-2 text-sm">
          {active ? (
            <span className="font-medium text-flat-primary">Used for new plans</span>
          ) : (
            <span className="text-flat-muted-fg">Not used for plans</span>
          )}
          {!active && (
            <Button size="sm" variant="ghost" loading={busy} onClick={onSetActive}>
              Plan with this
            </Button>
          )}
        </div>
      )}
    </Card>
  )
}

function AddVehicle() {
  const queryClient = useQueryClient()
  const [vin, setVin] = useState('')
  const add = useMutation({
    mutationFn: async () => {
      const v = vin.trim().toUpperCase()
      if (v.length < 11) throw new Error('Enter a VIN with at least 11 characters.')
      return { vin: v, result: await onboardVehicleFromVin(v) }
    },
    onSuccess: async ({ vin: v, result }) => {
      setVin('')
      try {
        await putVehicleState(v, initialVehicleStateAfterOnboard(result.profile))
      } catch (e) {
        console.warn('Could not seed vehicle state', e)
      }
      await queryClient.invalidateQueries({ queryKey: ['fleet'] })
    },
  })
  const warnings = add.data?.result.warnings ?? []
  return (
    <form
      className="space-y-2"
      onSubmit={(e) => {
        e.preventDefault()
        add.mutate()
      }}
    >
      <Field
        label="Add a vehicle by VIN"
        htmlFor="vin"
        hint="We look up its make, model, and range from the VIN."
        error={add.isError ? (add.error instanceof ApiError || add.error instanceof Error ? add.error.message : 'Could not add the vehicle.') : undefined}
      >
        <div className="flex gap-2">
          <Input
            id="vin"
            value={vin}
            onChange={(e) => setVin(e.target.value.toUpperCase())}
            placeholder="5YJ3E1EA1JF000000"
            autoComplete="off"
            spellCheck={false}
            className="font-mono uppercase"
          />
          <Button type="submit" variant="primary" loading={add.isPending} iconLeft={<Plus className="size-4" />}>
            Add
          </Button>
        </div>
      </Field>
      {warnings.length > 0 && (
        <ul className="list-inside list-disc text-sm text-flat-warning">
          {warnings.map((w) => (
            <li key={w}>{w}</li>
          ))}
        </ul>
      )}
    </form>
  )
}

export default function FleetPanel() {
  const queryClient = useQueryClient()
  const fleet = useQuery({ queryKey: ['fleet'], queryFn: getFleetStatus, refetchInterval: 30_000 })
  const me = useQuery({ queryKey: ['user', 'me'], queryFn: getUserMe, retry: 1, staleTime: 60_000 })
  const setActive = useMutation({
    mutationFn: (vin: string) => setActiveVehicleVin(vin),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['user', 'me'] }),
  })
  const activeVin = me.data?.active_vehicle_vin?.trim()
  const vehicles = fleet.data ?? []

  return (
    <div className="space-y-5">
      <PageHeader title="Fleet" description="Your vehicles, what they have left, and where they were last seen." />
      <AddVehicle />
      {setActive.isError && <p className="text-sm text-flat-danger">Couldn't save the vehicle for plans. Try again.</p>}
      {fleet.isLoading && <SkeletonRows count={3} />}
      {fleet.isError && <EmptyState size="sm" icon={<Car />} title={describeError(fleet.error, 'vehicles')} action={{ label: 'Try again', onClick: () => void fleet.refetch() }} />}
      {fleet.isSuccess && vehicles.length === 0 && (
        <EmptyState size="sm" icon={<Car />} title="No vehicles yet" body="Add one by its VIN above, and it's ready for trip plans." />
      )}
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
        {vehicles.map((v, i) => (
          <VehicleCard
            key={v.vin}
            v={v}
            index={i}
            active={activeVin === v.vin}
            busy={setActive.isPending && setActive.variables === v.vin}
            onSetActive={me.isSuccess ? () => setActive.mutate(v.vin) : undefined}
          />
        ))}
      </div>
    </div>
  )
}
