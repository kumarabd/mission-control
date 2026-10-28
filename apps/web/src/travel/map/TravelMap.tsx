import { ControlPosition, Map } from '@vis.gl/react-google-maps'
import { ColorScheme } from '@vis.gl/react-google-maps'
import { useTheme } from '../../theme/theme-context'
import { useRouteStore } from '../stores/routeStore'
import {
  ChargerMarker,
  MapBindings,
  MapPickPreviewMarker,
  MapRouteClickHandler,
  RoutePolyline,
  RouteStopsMarkers,
} from './layers'

const SAN_JOSE = { lat: 37.3382, lng: -121.8863 }
const MAP_ID = import.meta.env.VITE_GOOGLE_MAPS_MAP_ID?.trim() || 'DEMO_MAP_ID'

/** The plan screen's map: the route, its stops, and map taps that stage a new stop. */
export function TravelMap() {
  const { theme } = useTheme()
  const plan = useRouteStore((s) => s.plan)
  const selectedStopIndex = useRouteStore((s) => s.selectedStopIndex)
  const setSelectedStopIndex = useRouteStore((s) => s.setSelectedStopIndex)

  return (
    <Map
      className="absolute inset-0 h-full w-full"
      mapId={MAP_ID}
      defaultCenter={SAN_JOSE}
      defaultZoom={10}
      clickableIcons={false}
      gestureHandling="greedy"
      zoomControl
      zoomControlOptions={{ position: ControlPosition.RIGHT_BOTTOM }}
      mapTypeControl={false}
      streetViewControl={false}
      fullscreenControl={false}
      colorScheme={theme === 'dark' ? ColorScheme.DARK : ColorScheme.LIGHT}
    >
      <MapBindings />
      <MapRouteClickHandler />
      <RoutePolyline />
      <MapPickPreviewMarker />
      <RouteStopsMarkers />
      {plan?.stops.map((stop, index) => (
        <ChargerMarker
          key={`${stop.name}-${stop.segmentIndex}-${index}`}
          stop={stop}
          index={index}
          selected={selectedStopIndex === index}
          onSelect={() => setSelectedStopIndex(index)}
        />
      ))}
    </Map>
  )
}
