import { APIProvider } from '@vis.gl/react-google-maps'
import { MapPinOff } from 'lucide-react'
import { Outlet, useLocation } from 'react-router-dom'
import { EmptyState } from '../components/ui'
import { GOOGLE_MAPS_API_KEY } from './config'
import { TravelMap } from './map/TravelMap'
import { TravelAuth } from './TravelAuth'

/**
 * Travel's frame. Plan is a docked panel beside a map (on a narrow screen the map sits on top). Fleet and Trips are
 * ordinary pages with no map. The Maps script still loads for all of them: trip rows look up place names with it.
 */
export default function TravelLayout() {
  const planning = useLocation().pathname === '/travel/plan'
  if (!GOOGLE_MAPS_API_KEY) {
    return (
      <EmptyState
        icon={<MapPinOff />}
        title="Maps isn't set up for this deployment"
        body="Travel needs a Google Maps key. Set VITE_GOOGLE_MAPS_API_KEY when building the image."
      />
    )
  }
  return (
    <TravelAuth>
      <APIProvider apiKey={GOOGLE_MAPS_API_KEY} libraries={['places', 'marker', 'geocoding']}>
        {planning ? (
          <div className="flex h-full min-h-0 flex-col lg:flex-row">
            <div className="relative order-1 h-[38vh] shrink-0 lg:order-2 lg:h-auto lg:flex-1">
              <TravelMap />
            </div>
            <section
              aria-label="Plan a trip"
              className="order-2 min-h-0 flex-1 overflow-y-auto border-t border-flat-border bg-flat-surface p-4 sm:p-5 lg:w-[26rem] lg:flex-none lg:border-r lg:border-t-0 xl:w-[28rem]"
            >
              <Outlet />
            </section>
          </div>
        ) : (
          <Outlet />
        )}
      </APIProvider>
    </TravelAuth>
  )
}
