import { ArrowRight, Fuel, Zap } from 'lucide-react'
import type { CSSProperties } from 'react'
import { Stat, Tag } from '../../components/ui'
import { cn } from '../../lib/cn'
import type { RoutePlanResponse, RoutePlanStop } from '../api/contract/routePlan'
import { arrivalEnduranceLabel, consumptionModelTags } from '../api/contract/routePlanDisplay'
import { useMapStore } from '../stores/mapStore'
import { routeEndPlace, routeStartPlace, useRouteStore } from '../stores/routeStore'
import { formatClock, formatCurrency, formatDistance, formatDuration } from '../utils/format'
import { formatPlannedStopSummary } from '../utils/routePlanStops'
import { computeTimelineTimes } from '../utils/timeline'

const isFuel = (s: RoutePlanStop) => s.stopType.toLowerCase() === 'fuel' || s.ice != null

/** Charge or fuel level as a short bar: danger when low, warning when getting there, success otherwise. */
function Level({ value, label }: { value: number; label: string }) {
  const tone = value < 20 ? 'bg-flat-danger' : value < 40 ? 'bg-flat-warning' : 'bg-flat-success'
  return (
    <span className="flex items-center gap-1.5">
      <span role="meter" aria-label={label} aria-valuemin={0} aria-valuemax={100} aria-valuenow={Math.round(value)} className="h-1.5 w-14 overflow-hidden rounded-full bg-flat-muted">
        <span className={cn('block h-full rounded-full', tone)} style={{ width: `${Math.max(0, Math.min(100, value))}%` }} />
      </span>
      <span className="w-8 tabular-nums">{Math.round(value)}%</span>
    </span>
  )
}

function Node({ kind, active }: { kind: 'origin' | 'stop' | 'via' | 'dest'; active?: boolean }) {
  return (
    <span
      aria-hidden
      className={cn(
        'absolute left-0 top-1 z-[1] flex size-5 items-center justify-center border-2 border-flat-surface transition-transform duration-[var(--duration-fast)] ease-[var(--ease-standard)]',
        kind === 'origin' && 'rounded-full bg-flat-foreground text-flat-background',
        kind === 'dest' && 'rounded-[4px] bg-flat-foreground text-flat-background',
        kind === 'via' && 'rounded-full bg-flat-warning text-flat-background',
        kind === 'stop' && 'rounded-full bg-flat-primary text-flat-on-primary',
        active && 'scale-125',
      )}
    />
  )
}

/** One entry on the itinerary; it fades in as the route reaches it (delay is its place along the route). */
function Entry({ at, children, className }: { at: number; children: React.ReactNode; className?: string }) {
  return (
    <li className={cn('travel-rise relative pl-8', className)} style={{ '--travel-delay': `${Math.round(at * 900)}ms` } as CSSProperties}>
      {children}
    </li>
  )
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between gap-3 text-base text-flat-muted-fg">
      <span className="min-w-0 truncate">{label}</span>
      <span className="shrink-0 tabular-nums text-flat-foreground">{value}</span>
    </div>
  )
}

export function PlanResult({ plan }: { plan: RoutePlanResponse }) {
  const panTo = useMapStore((s) => s.panTo)
  const selected = useRouteStore((s) => s.selectedStopIndex)
  const setSelected = useRouteStore((s) => s.setSelectedStopIndex)
  const routeStops = useRouteStore((s) => s.routeStops)
  const origin = routeStartPlace(routeStops)
  const dest = routeEndPlace(routeStops)
  const times = computeTimelineTimes(plan)
  const middle = routeStops.slice(1, -1).filter((r) => r.place != null)
  const total = middle.length + 2
  const arrival = arrivalEnduranceLabel(plan)
  const conf = plan.consumption.confidence <= 1 ? plan.consumption.confidence * 100 : plan.consumption.confidence
  const tags = [
    ...(plan.route.trafficConditions?.trim() ? [`Traffic: ${plan.route.trafficConditions}`] : []),
    ...consumptionModelTags(plan.consumption),
    `Model confidence ${conf.toFixed(0)}%`,
  ]
  const homeEq = plan.cost.ev?.equivHomeCost ?? 0

  return (
    <div className="space-y-6" aria-label="Trip plan" role="region">
      <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">
        <Stat label="Distance" value={formatDistance(plan.route.totalDistanceKm * 1000)} />
        <Stat label="Drive time" value={formatDuration(Math.round(plan.route.totalDurationSec))} />
        <Stat label="Cost" value={formatCurrency(plan.cost.totalCost)} />
      </div>

      {plan.warnings && plan.warnings.length > 0 && (
        <ul className="space-y-1 rounded-md bg-flat-warning-muted px-3 py-2 text-sm text-flat-warning">
          {plan.warnings.map((w) => (
            <li key={w}>{w}</li>
          ))}
        </ul>
      )}

      <section aria-labelledby="itinerary">
        <h2 id="itinerary" className="mb-3 text-base font-medium text-flat-foreground">
          Itinerary
        </h2>
        <div className="relative">
          <span aria-hidden className="travel-spine absolute bottom-3 left-[9px] top-3 w-px bg-flat-border-strong" />
          <ul className="space-y-5">
            <Entry at={0}>
              <Node kind="origin" />
              <p className="text-sm text-flat-muted-fg">Depart · {formatClock(times.originDepart)}</p>
              <p className="text-base font-medium text-flat-foreground">{origin?.name || 'Start'}</p>
            </Entry>

            {middle.map((row, k) => {
              const at = (k + 1) / total
              const psi = row.planStopIndex
              const stop = row.fromPlan && typeof psi === 'number' ? plan.stops[psi] : undefined
              if (!stop || psi === undefined) {
                return (
                  <Entry key={row.id} at={at}>
                    <Node kind="via" />
                    <p className="text-sm text-flat-muted-fg">Via</p>
                    <p className="text-base font-medium text-flat-foreground">{row.place!.name}</p>
                  </Entry>
                )
              }
              const t = times.stops[psi]
              const on = selected === psi
              const fuel = isFuel(stop)
              const arr = fuel ? stop.ice?.arrivalFuelLevel : stop.ev?.arrivalSoC
              const dep = fuel ? stop.ice?.departureFuelLevel : stop.ev?.departureSoC
              return (
                <Entry key={row.id} at={at}>
                  <Node kind="stop" active={on} />
                  <button
                    type="button"
                    aria-pressed={on}
                    onClick={() => {
                      setSelected(psi)
                      panTo(stop.location.lat, stop.location.lng, 12)
                    }}
                    className={cn(
                      '-mx-2 block w-[calc(100%+1rem)] rounded-md px-2 py-1.5 text-left transition-colors',
                      on ? 'bg-flat-tint' : 'hover:bg-flat-muted',
                    )}
                  >
                    <p className="flex items-center gap-1.5 text-sm capitalize text-flat-muted-fg">
                      {fuel ? <Fuel className="size-3.5" aria-hidden /> : <Zap className="size-3.5" aria-hidden />}
                      {formatPlannedStopSummary(stop)}
                    </p>
                    <p className="text-base font-medium text-flat-foreground">{row.place!.name}</p>
                    {t && (
                      <p className="text-sm tabular-nums text-flat-muted-fg">
                        {formatClock(t.arrive)} → {formatClock(t.depart)}
                      </p>
                    )}
                    {arr != null && dep != null && (
                      <div className="mt-1.5 flex flex-wrap items-center gap-x-2 gap-y-1 text-xs text-flat-muted-fg">
                        <Level value={arr} label={fuel ? 'Fuel on arrival' : 'Charge on arrival'} />
                        <ArrowRight className="size-3 text-flat-subtle-fg" aria-hidden />
                        <Level value={dep} label={fuel ? 'Fuel on departure' : 'Charge on departure'} />
                      </div>
                    )}
                  </button>
                </Entry>
              )
            })}

            <Entry at={1}>
              <Node kind="dest" />
              <p className="text-sm text-flat-muted-fg">
                Arrive · {formatClock(times.destArrive)}
                {arrival ? ` · ${arrival}` : ''}
              </p>
              <p className="text-base font-medium text-flat-foreground">{dest?.name || 'Destination'}</p>
            </Entry>
          </ul>
        </div>
      </section>

      <section aria-labelledby="cost" className="space-y-1.5">
        <h2 id="cost" className="mb-2 text-base font-medium text-flat-foreground">
          Cost
        </h2>
        <Row label="Paid at stops" value={formatCurrency(plan.cost.stopSessionCost)} />
        {homeEq > 0 && <Row label="Home electricity equivalent" value={formatCurrency(homeEq)} />}
        <Row label="Time at stops" value={`${Math.round(plan.cost.timeAtStopsMin)} min`} />
        {plan.cost.stopCosts.map((sc) => (
          <Row key={sc.stopName + sc.timeMin} label={sc.stopName} value={`${formatCurrency(sc.cost)} · ${Math.round(sc.timeMin)} min`} />
        ))}
        <div className="flex justify-between border-t border-flat-border pt-2 text-base font-medium text-flat-foreground">
          <span>Total</span>
          <span className="tabular-nums">{formatCurrency(plan.cost.totalCost)}</span>
        </div>
        <p className="text-sm text-flat-muted-fg">{formatCurrency(plan.cost.perMile)} per mile</p>
      </section>

      <div className="flex flex-wrap gap-1.5">
        {tags.map((t) => (
          <Tag key={t}>{t}</Tag>
        ))}
      </div>
    </div>
  )
}
