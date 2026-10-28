import { useApiIsLoaded, useMapsLibrary } from '@vis.gl/react-google-maps'
import { LocateFixed, Loader2 } from 'lucide-react'
import { useCallback, useEffect, useId, useRef, useState, type ReactNode } from 'react'
import { Input } from '../../components/ui'
import type { Place } from '../stores/routeStore'
import { resolvePlaceFromDeviceGeolocation } from '../utils/deviceOriginPlace'

function geolocationErrorMessage(code: number): string {
  switch (code) {
    case 1:
      return 'Location access is blocked. Allow it for this site in your browser settings.'
    case 2:
      return "Couldn't work out where you are. Try again, or search for an address."
    case 3:
      return 'Finding your location timed out. Search for an address instead.'
    default:
      return "Couldn't get your location."
  }
}

type Props = {
  placeholder: string
  value: Place | null
  onChange: (place: Place | null) => void
  onEnter?: () => void
  onEscape?: () => void
  /** Fill from the device's GPS (the starting point only). */
  showMyLocationButton?: boolean
  label: string
  trailing?: ReactNode
}

export function PlaceInput({ placeholder, value, onChange, onEnter, onEscape, showMyLocationButton, label, trailing }: Props) {
  const listId = useId()
  const mapsLoaded = useApiIsLoaded()
  const places = useMapsLibrary('places')
  const geocoding = useMapsLibrary('geocoding')
  const [text, setText] = useState(value?.name ?? '')
  // When the place changes from outside (map pick, reverse, planned stop), show its name.
  const placeKey = `${value?.name ?? ''}|${value?.lat}|${value?.lng}`
  const [seenPlace, setSeenPlace] = useState(placeKey)
  if (seenPlace !== placeKey) {
    setSeenPlace(placeKey)
    setText(value?.name ?? '')
  }
  const [open, setOpen] = useState(false)
  const [active, setActive] = useState(0)
  const [locating, setLocating] = useState(false)
  const [geoError, setGeoError] = useState<string | null>(null)
  const [geoHint, setGeoHint] = useState<string | null>(null)
  const [predictions, setPredictions] = useState<google.maps.places.PlacePrediction[]>([])
  const session = useRef<google.maps.places.AutocompleteSessionToken | null>(null)
  const debounce = useRef<ReturnType<typeof setTimeout> | null>(null)
  const seq = useRef(0)

  useEffect(() => {
    if (places) session.current = new google.maps.places.AutocompleteSessionToken()
  }, [places])

  const search = useCallback(
    async (input: string) => {
      if (!places || input.trim().length < 2) return setPredictions([])
      const mine = ++seq.current
      try {
        const { suggestions } = await google.maps.places.AutocompleteSuggestion.fetchAutocompleteSuggestions({
          input: input.trim(),
          sessionToken: session.current ?? undefined,
        })
        if (mine !== seq.current) return
        setPredictions(suggestions.map((s) => s.placePrediction).filter((p): p is google.maps.places.PlacePrediction => p != null))
        setActive(0)
      } catch {
        if (mine === seq.current) setPredictions([])
      }
    },
    [places],
  )

  const choose = useCallback(
    async (p: google.maps.places.PlacePrediction) => {
      try {
        const { place } = await p.toPlace().fetchFields({ fields: ['location', 'displayName', 'formattedAddress'] })
        const loc = place.location
        if (!loc) return
        const name = place.displayName ?? place.formattedAddress ?? p.text.text
        onChange({ name, lat: loc.lat(), lng: loc.lng(), placeId: place.id })
        setText(name)
        setOpen(false)
        setPredictions([])
        session.current = new google.maps.places.AutocompleteSessionToken()
      } catch {
        /* keep what was typed */
      }
    },
    [onChange],
  )

  const locate = useCallback(async () => {
    setGeoError(null)
    setGeoHint(null)
    if (!mapsLoaded || !geocoding) return setGeoError('The map is still loading. Try again in a moment.')
    if (!navigator.geolocation) return setGeoError("This browser can't share your location.")
    setLocating(true)
    try {
      const { place, geoHint } = await resolvePlaceFromDeviceGeolocation()
      onChange(place)
      setText(place.name)
      setOpen(false)
      setPredictions([])
      setGeoHint(geoHint)
    } catch (err) {
      const code = err && typeof err === 'object' && 'code' in err ? Number((err as GeolocationPositionError).code) : 0
      setGeoError(geolocationErrorMessage(code))
    } finally {
      setLocating(false)
    }
  }, [mapsLoaded, geocoding, onChange])

  const showList = open && predictions.length > 0
  return (
    <div className="min-w-0 flex-1">
      <div className="flex items-center gap-1.5">
        <div className="relative min-w-0 flex-1">
          <Input
            type="text"
            role="combobox"
            aria-label={label}
            aria-expanded={showList}
            aria-controls={listId}
            aria-autocomplete="list"
            autoComplete="off"
            placeholder={placeholder}
            value={text}
            onChange={(e) => {
              setGeoError(null)
              setGeoHint(null)
              setText(e.target.value)
              setOpen(true)
              if (debounce.current) clearTimeout(debounce.current)
              debounce.current = setTimeout(() => void search(e.target.value), 200)
            }}
            onFocus={() => setOpen(true)}
            onBlur={() => window.setTimeout(() => setOpen(false), 160)}
            onKeyDown={(e) => {
              if (e.key === 'ArrowDown' && showList) {
                e.preventDefault()
                setActive((i) => Math.min(i + 1, predictions.length - 1))
              } else if (e.key === 'ArrowUp' && showList) {
                e.preventDefault()
                setActive((i) => Math.max(i - 1, 0))
              } else if (e.key === 'Enter') {
                e.preventDefault()
                if (showList && predictions[active]) void choose(predictions[active])
                else onEnter?.()
              } else if (e.key === 'Escape') {
                e.preventDefault()
                onEscape?.()
                setOpen(false)
              }
            }}
          />
          {showList && (
            <ul
              id={listId}
              role="listbox"
              className="absolute inset-x-0 top-full z-50 mt-1 max-h-56 overflow-auto rounded-md border border-flat-border-strong bg-flat-surface-raised py-1 shadow-2"
            >
              {predictions.map((p, i) => (
                <li key={p.placeId} role="option" aria-selected={i === active}>
                  <button
                    type="button"
                    className={`w-full px-3 py-1.5 text-left text-base text-flat-foreground ${i === active ? 'bg-flat-muted' : 'hover:bg-flat-muted'}`}
                    onMouseDown={(e) => e.preventDefault()}
                    onMouseEnter={() => setActive(i)}
                    onClick={() => void choose(p)}
                  >
                    {p.text.text}
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>
        {showMyLocationButton && (
          <button
            type="button"
            onClick={() => void locate()}
            disabled={locating || !geocoding}
            title="Use your current location"
            aria-label="Use your current location"
            className="flex size-9 shrink-0 items-center justify-center rounded-sm border border-flat-border text-flat-muted-fg transition-colors hover:border-flat-border-strong hover:text-flat-primary disabled:opacity-50"
          >
            {locating ? <Loader2 className="size-4 animate-spin" /> : <LocateFixed className="size-4" />}
          </button>
        )}
        {trailing}
      </div>
      {geoError && (
        <p className="mt-1 text-xs text-flat-danger" role="alert">
          {geoError}
        </p>
      )}
      {geoHint && (
        <p className="mt-1 text-xs text-flat-warning" role="status">
          {geoHint}
        </p>
      )}
    </div>
  )
}
