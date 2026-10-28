import { useMemo } from 'react'
import { useTheme } from '../../theme/theme-context'

/** The theme's primary colour, read from the CSS variable, for strokes the map draws itself (it can't take a class). */
export function useSignalColor() {
  const { theme } = useTheme()
  // `theme` is in the deps because the variable's value changes with it.
  // eslint-disable-next-line react-hooks/exhaustive-deps
  return useMemo(() => ({ line: getComputedStyle(document.documentElement).getPropertyValue('--theme-flat-primary').trim() || '#5c9cff' }), [theme])
}

/** How long the planned route takes to draw; the itinerary spine's CSS animation (index.css) uses the same 1400ms. */
export const ROUTE_DRAW_MS = 1400
