import { useQuery } from '@tanstack/react-query'
import { Link } from 'react-router-dom'
import { Navigation, RotateCcw } from 'lucide-react'
import { Button, PageHeader } from '../../components/ui'
import { getUserMe } from '../api/fleet'
import { getFleetStatus } from '../api/vehicles'
import { useRoutePlanner } from '../hooks/useRoutePlanner'
import { useRouteStore } from '../stores/routeStore'
import { PlanResult } from './PlanResult'
import { StopList } from './StopList'

/** Which vehicle a plan is for: the active one, else the first in the fleet (what the planner itself falls back to). */
function usePlanningVehicle() {
  const me = useQuery({ queryKey: ['user', 'me'], queryFn: getUserMe, retry: 1, staleTime: 60_000 })
  const fleet = useQuery({ queryKey: ['fleet'], queryFn: getFleetStatus, refetchInterval: 30_000 })
  const vehicles = fleet.data ?? []
  const active = me.data?.active_vehicle_vin?.trim()
  const vehicle = vehicles.find((v) => v.vin === active) ?? [...vehicles].sort((a, b) => a.vin.localeCompare(b.vin))[0]
  return { vehicle, ready: fleet.isSuccess }
}

export default function PlanPanel() {
  const routeStops = useRouteStore((s) => s.routeStops)
  const plan = useRouteStore((s) => s.plan)
  const planning = useRouteStore((s) => s.isPlanning)
  const error = useRouteStore((s) => s.planErrorMessage)
  const reset = useRouteStore((s) => s.resetRoutePlanner)
  const { runPlan } = useRoutePlanner()
  const { vehicle, ready } = usePlanningVehicle()

  const userRows = routeStops.filter((r) => !r.fromPlan)
  const canPlan = userRows.length >= 2 && userRows.every((r) => r.place != null)

  return (
    <div className="space-y-5">
      <PageHeader
        title="Plan a trip"
        description="Search for a destination or tap the map. Charging and fuel stops are added along the way."
        actions={
          plan && (
            <Button variant="ghost" size="sm" iconLeft={<RotateCcw className="size-3.5" />} onClick={reset}>
              Start over
            </Button>
          )
        }
      />

      <div>
        <StopList canPlan={canPlan} onPlan={() => void runPlan()} />
        <Button
          variant="primary"
          fullWidth
          className="mt-4"
          disabled={!canPlan}
          loading={planning}
          iconLeft={<Navigation className="size-4" />}
          onClick={() => void runPlan()}
        >
          {plan ? 'Replan' : 'Plan route'}
        </Button>
        {ready && (
          <p className="mt-2 text-sm text-flat-muted-fg">
            {vehicle ? (
              <>
                Planning for <span className="text-flat-foreground">{vehicle.name}</span>.{' '}
                <Link to="/travel/fleet" className="text-flat-primary">
                  Change vehicle
                </Link>
              </>
            ) : (
              <>
                You need a vehicle to plan.{' '}
                <Link to="/travel/fleet" className="text-flat-primary">
                  Add one in Fleet
                </Link>
              </>
            )}
          </p>
        )}
      </div>

      {error && (
        <p role="alert" className="rounded-md bg-flat-danger-muted px-3 py-2 text-sm text-flat-danger">
          {error}
        </p>
      )}

      {plan && <PlanResult plan={plan} />}
    </div>
  )
}
