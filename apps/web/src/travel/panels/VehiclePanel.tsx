import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, Copy, Trash2 } from 'lucide-react'
import { useState, type ReactNode } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { Badge, Button, Card, EmptyState, Field, Input, SkeletonRows, toast, useConfirm } from '../../components/ui'
import { cn } from '../../lib/cn'
import { ApiError } from '../api/client'
import type { LiveStateEditBlock, LiveStateEditField, VehicleDetailResponse, VehicleProfileWire } from '../api/vehicleProfile'
import { clampPercent, clampToRange, vehicleStateWireFromSnapshot } from '../api/vehicleStateMerge'
import { deleteVehicle, getVehicleDetail, putVehicleState, updateVehicleProfile, VEHICLE_CONNECTOR_TYPE_VALUES, type VehicleStateWire } from '../api/vehicles'

const DRIVETRAIN: Record<string, string> = { EV: 'Battery electric', PHEV: 'Plug-in hybrid', ICE: 'Gas or diesel' }
const FUEL_GRADE: Record<string, string> = { REGULAR: 'Regular', PREMIUM: 'Premium', DIESEL: 'Diesel' }
const CONNECTOR: Record<string, string> = { TESLA: 'Tesla (NACS)', J1772: 'J1772 (Type 1 AC)', CHAdeMO: 'CHAdeMO', CCS: 'CCS (Combo)' }

const detailKey = (vin: string) => ['vehicle', vin, 'detail'] as const

function Section({ title, hint, children }: { title: string; hint?: string; children: ReactNode }) {
  return (
    <section className="space-y-3">
      <div>
        <h2 className="text-base font-medium text-flat-foreground">{title}</h2>
        {hint && <p className="text-sm text-flat-muted-fg">{hint}</p>}
      </div>
      {children}
    </section>
  )
}

function Facts({ rows }: { rows: [string, ReactNode][] }) {
  return (
    <dl className="divide-y divide-flat-border rounded-md border border-flat-border">
      {rows.map(([k, v]) => (
        <div key={k} className="flex items-baseline justify-between gap-4 px-3 py-2 text-base">
          <dt className="text-flat-muted-fg">{k}</dt>
          <dd className="min-w-0 break-words text-right text-flat-foreground">{v === undefined || v === '' ? '—' : v}</dd>
        </div>
      ))}
    </dl>
  )
}

function applyField(body: VehicleStateWire, key: string, raw: number) {
  if (key === 'state_of_charge') body.state_of_charge = clampPercent(raw)
  else if (key === 'battery_temp_c') body.battery_temp_c = Number.isFinite(raw) ? raw : 25
  else if (key === 'fuel_level') body.fuel_level = clampPercent(raw)
}

function FieldControl({ field, value, onChange }: { field: LiveStateEditField; value: number; onChange: (n: number) => void }) {
  const t = field.type.toLowerCase()
  const step = field.step ?? 1
  if (t === 'percent') {
    const min = field.min ?? 0
    const max = field.max ?? 100
    return (
      <div className="space-y-1.5">
        <div className="flex items-baseline justify-between text-base">
          <label htmlFor={field.key} className="text-flat-foreground">
            {field.label}
          </label>
          <span className="font-mono tabular-nums">{Math.round(clampToRange(value, min, max))}%</span>
        </div>
        <input
          id={field.key}
          type="range"
          min={min}
          max={max}
          step={step}
          value={clampToRange(value, min, max)}
          onChange={(e) => onChange(Number(e.target.value))}
          className="w-full accent-[var(--color-flat-primary)]"
        />
      </div>
    )
  }
  if (t === 'number') {
    return (
      <Field label={field.label} htmlFor={field.key}>
        <Input id={field.key} type="number" step={step} value={value} onChange={(e) => onChange(Number(e.target.value))} />
      </Field>
    )
  }
  return null
}

/** Renders `live_state_edit` from the engine: one control per field type, no drivetrain branching here. */
function LiveState({ vin, blocks, snapshot, drivetrain }: { vin: string; blocks?: LiveStateEditBlock[]; snapshot: Record<string, unknown> | undefined; drivetrain: string }) {
  const queryClient = useQueryClient()
  const [values, setValues] = useState<Record<string, number>>(() => {
    const next: Record<string, number> = {}
    for (const b of blocks ?? []) for (const f of b.fields) next[f.key] = f.value
    return next
  })

  const save = useMutation({
    mutationFn: () => {
      const body: VehicleStateWire = { ...vehicleStateWireFromSnapshot(snapshot, drivetrain), last_updated_unix: Math.floor(Date.now() / 1000) }
      for (const [k, v] of Object.entries(values)) applyField(body, k, v)
      return putVehicleState(vin, body)
    },
    onSuccess: () => {
      toast.success('Saved')
      void queryClient.invalidateQueries({ queryKey: detailKey(vin) })
      void queryClient.invalidateQueries({ queryKey: ['fleet'] })
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : "Couldn't save the reading."),
  })

  if (!blocks?.length) return null
  return (
    <>
      {blocks.map((b) => (
        <Section key={b.title} title={b.title} hint={b.subtitle}>
          <Card className="space-y-4">
            {b.fields.map((f) => (values[f.key] === undefined ? null : <FieldControl key={f.key} field={f} value={values[f.key]} onChange={(n) => setValues((p) => ({ ...p, [f.key]: n }))} />))}
          </Card>
        </Section>
      ))}
      <Button variant="secondary" loading={save.isPending} onClick={() => save.mutate()}>
        Save readings
      </Button>
    </>
  )
}

function Connectors({ vin, profile }: { vin: string; profile: VehicleProfileWire }) {
  const queryClient = useQueryClient()
  const list = profile.connector_types ?? []
  const save = useMutation({
    mutationFn: (next: string[]) => updateVehicleProfile(vin, { ...profile, connector_types: next }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: detailKey(vin) }),
    onError: (e) => toast.error(e instanceof Error ? e.message : "Couldn't update connectors."),
  })
  const have = new Set(list.map((c) => c.toUpperCase()))
  return (
    <div className="space-y-2" role="group" aria-label="Connector types">
      <div className="flex flex-wrap gap-2">
        {VEHICLE_CONNECTOR_TYPE_VALUES.map((c) => {
          const on = have.has(c.toUpperCase())
          return (
            <button
              key={c}
              type="button"
              aria-pressed={on}
              disabled={save.isPending}
              title={on && list.length <= 1 ? 'An electric vehicle needs at least one connector' : undefined}
              onClick={() => {
                if (on && list.length <= 1) return // the last connector stays
                save.mutate(on ? list.filter((x) => x.toUpperCase() !== c.toUpperCase()) : [...list, c])
              }}
              className={cn(
                'rounded-sm border px-2.5 py-1.5 text-sm font-medium transition-colors disabled:opacity-50',
                on ? 'border-flat-primary bg-flat-tint text-flat-primary' : 'border-flat-border text-flat-muted-fg hover:border-flat-border-strong hover:text-flat-foreground',
              )}
            >
              {CONNECTOR[c] ?? c}
            </button>
          )
        })}
      </div>
      <p className="text-sm text-flat-muted-fg">Used to find chargers that fit. Each change saves right away.</p>
    </div>
  )
}

function Planning({ vin, profile }: { vin: string; profile: VehicleProfileWire }) {
  const queryClient = useQueryClient()
  const [minSoc, setMinSoc] = useState(profile.planning_min_soc_percent && profile.planning_min_soc_percent > 0 ? profile.planning_min_soc_percent : 15)
  const [chargeTo, setChargeTo] = useState(profile.planning_charge_to_percent && profile.planning_charge_to_percent > 0 ? profile.planning_charge_to_percent : 80)
  const [rangeMi, setRangeMi] = useState(profile.epa_range_miles && profile.epa_range_miles > 0 ? String(Math.round(profile.epa_range_miles)) : '')

  const save = useMutation({
    mutationFn: () => {
      const mi = Number.parseFloat(rangeMi.replace(/,/g, '.').trim())
      if (!Number.isFinite(mi) || mi <= 0) throw new Error('Enter a range in miles, greater than 0.')
      if (chargeTo < minSoc) throw new Error('Charge to must be at least the arrival minimum.')
      return updateVehicleProfile(vin, { ...profile, planning_min_soc_percent: minSoc, planning_charge_to_percent: chargeTo, epa_range_miles: mi })
    },
    onSuccess: () => {
      toast.success('Planning preferences saved')
      void queryClient.invalidateQueries({ queryKey: detailKey(vin) })
      void queryClient.invalidateQueries({ queryKey: ['fleet'] })
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : "Couldn't save."),
  })
  return (
    <Card className="space-y-4">
      <div className="grid grid-cols-2 gap-3">
        <Field label="Arrive with at least (%)" htmlFor="min-soc">
          <Input id="min-soc" type="number" min={0} max={100} value={minSoc} onChange={(e) => setMinSoc(Number(e.target.value))} />
        </Field>
        <Field label="Charge to (%)" htmlFor="charge-to">
          <Input id="charge-to" type="number" min={0} max={100} value={chargeTo} onChange={(e) => setChargeTo(Number(e.target.value))} />
        </Field>
      </div>
      <Field label="Full-charge range (miles)" htmlFor="range" hint="Used to estimate how much each leg uses.">
        <Input id="range" type="number" min={1} inputMode="numeric" value={rangeMi} onChange={(e) => setRangeMi(e.target.value)} placeholder="e.g. 250" />
      </Field>
      <Button variant="secondary" loading={save.isPending} onClick={() => save.mutate()}>
        Save planning preferences
      </Button>
    </Card>
  )
}

export default function VehiclePanel() {
  const { vin = '' } = useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const confirm = useConfirm()
  const remove = useMutation({
    mutationFn: () => deleteVehicle(vin),
    onSuccess: async () => {
      toast.success('Vehicle removed')
      queryClient.removeQueries({ queryKey: ['vehicle', vin] })
      await Promise.all(['fleet', 'garage', 'drives', 'drive-stats', 'trips', 'user'].map((k) => queryClient.invalidateQueries({ queryKey: [k] })))
      navigate('/travel/fleet')
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : "Couldn't remove the vehicle."),
  })
  const q = useQuery({ queryKey: detailKey(vin), queryFn: () => getVehicleDetail(vin), enabled: Boolean(vin) })
  const data: VehicleDetailResponse | undefined = q.data
  const p = data?.profile?.vin === vin ? data.profile : undefined
  const isEV = p?.drivetrain === 'EV' || p?.drivetrain === 'PHEV'
  // Remount the readings form when the server's values change, so it restarts from them.
  const liveKey = JSON.stringify((data?.live_state_edit ?? []).map((b) => b.fields.map((f) => [f.key, f.value])))
  const title = p ? [p.make, p.model].filter(Boolean).join(' ').trim() || 'Vehicle' : 'Vehicle'

  return (
    <div className="mx-auto w-full max-w-2xl space-y-6">
      <div className="space-y-3">
        <Link to="/travel/fleet" className="inline-flex items-center gap-1.5 text-sm text-flat-muted-fg no-underline hover:text-flat-foreground hover:no-underline">
          <ArrowLeft className="size-3.5" aria-hidden />
          Fleet
        </Link>
        <div>
          <h1 className="text-xl text-flat-foreground md:text-2xl">{title}</h1>
          <div className="mt-1 flex flex-wrap items-center gap-2">
            {p && <Badge tone="neutral">{DRIVETRAIN[p.drivetrain] ?? p.drivetrain}</Badge>}
            {p && p.year > 0 && <Badge tone="neutral">{p.year}</Badge>}
            <button
              type="button"
              onClick={() => void navigator.clipboard.writeText(vin).then(() => toast.success('VIN copied'))}
              className="inline-flex items-center gap-1 font-mono text-xs text-flat-subtle-fg hover:text-flat-foreground"
              aria-label="Copy VIN"
            >
              {vin}
              <Copy className="size-3" aria-hidden />
            </button>
          </div>
        </div>
      </div>

      {q.isLoading && <SkeletonRows count={5} />}
      {q.isError && (
        <EmptyState
          size="sm"
          title={q.error instanceof ApiError && q.error.status === 404 ? "This vehicle isn't in your fleet" : "Couldn't load this vehicle"}
          action={{ label: 'Back to Fleet', to: '/travel/fleet' }}
        />
      )}

      {p && data && (
        <>
          <LiveState key={liveKey} vin={vin} blocks={data.live_state_edit} snapshot={data.state} drivetrain={p.drivetrain} />

          {isEV ? (
            <>
              <Section title="Electric" hint="Battery and charging, used when planning.">
                <Facts
                  rows={[
                    ['Battery', p.battery_capacity_kwh != null ? `${p.battery_capacity_kwh} kWh` : undefined],
                    ['Fastest charging', p.max_charge_power_kw != null ? `${p.max_charge_power_kw} kW` : undefined],
                  ]}
                />
                <Connectors vin={vin} profile={p} />
              </Section>
              <Section title="Trip planning" hint="How the planner treats this vehicle.">
                <Planning key={`${p.planning_min_soc_percent}|${p.planning_charge_to_percent}|${p.epa_range_miles}`} vin={vin} profile={p} />
              </Section>
            </>
          ) : (
            <Section title="Fuel" hint="Tank and economy, used when planning.">
              <Facts
                rows={[
                  ['Tank', p.fuel_tank_size_liters != null ? `${(p.fuel_tank_size_liters / 3.785411784).toFixed(1)} gal` : undefined],
                  ['Fuel grade', p.fuel_grade ? (FUEL_GRADE[p.fuel_grade] ?? p.fuel_grade) : undefined],
                  ['City economy', p.epa_mpg_city != null ? `${p.epa_mpg_city} mpg` : undefined],
                  ['Highway economy', p.epa_mpg_highway != null ? `${p.epa_mpg_highway} mpg` : undefined],
                ]}
              />
            </Section>
          )}

          <Section title="Remove">
            <p className="text-sm text-flat-muted-fg">
              Removes this vehicle, its planned trips and its readings. Drives you recorded stay in your history.
            </p>
            <Button
              variant="outline"
              iconLeft={<Trash2 className="size-4" />}
              loading={remove.isPending}
              onClick={async () => {
                if (await confirm({ title: `Remove ${title}?`, body: 'It leaves your fleet and garage, and any trips planned for it are deleted.', confirmLabel: 'Remove', tone: 'danger' })) remove.mutate()
              }}
            >
              Remove vehicle
            </Button>
          </Section>

          <Section title="Profile">
            <Facts
              rows={[
                ['Make', p.make],
                ['Model', p.model],
                ['Year', p.year > 0 ? p.year : undefined],
                ['Drivetrain', DRIVETRAIN[p.drivetrain] ?? p.drivetrain],
              ]}
            />
          </Section>
        </>
      )}
    </div>
  )
}

