/**
 * The World graph's shared visual contract. The same values are used by the
 * native client's WorldGraphStyle, so the graph reads the same on web, macOS
 * and iPad/iPhone. Keep this file and the Swift token file in sync.
 */
export type WorldGraphMode = 'light' | 'dark'

export type WorldGraphTokens = {
  canvas: string
  surface: string
  border: string
  borderStrong: string
  text: string
  muted: string
  primary: string
  accent: string
  warning: string
  danger: string
  success: string
  scheduled: string
}

export const WORLD_GRAPH_TOKENS: Record<WorldGraphMode, WorldGraphTokens> = {
  light: {
    canvas: '#f1f3ec',
    surface: '#ffffff',
    border: '#ced1c5',
    borderStrong: '#aab4a5',
    text: '#18211b',
    muted: '#566159',
    primary: '#4e6a37',
    accent: '#2e6f7e',
    warning: '#8a6619',
    danger: '#9a4c3e',
    success: '#35734a',
    scheduled: '#1b3656',
  },
  dark: {
    canvas: '#151916',
    surface: '#191d1b',
    border: '#313a35',
    borderStrong: '#455047',
    text: '#e8eee9',
    muted: '#a8b2aa',
    primary: '#a9c985',
    accent: '#74b9c8',
    warning: '#f2c879',
    danger: '#e6a18c',
    success: '#8fce99',
    scheduled: '#c6e2ff',
  },
}

/** Entity types get these in alphabetical order; after six they repeat. */
export const WORLD_GRAPH_TYPE_KEYS = [
  'primary',
  'accent',
  'warning',
  'danger',
  'success',
  'scheduled',
] as const
