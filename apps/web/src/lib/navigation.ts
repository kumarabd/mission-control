export type NavStatus = 'available' | 'soon'

export type NavItem = {
  to: string
  label: string
  icon: string
  description?: string
  matchPrefix?: string
  status?: NavStatus
  badgeKey?: string
}

export type NavGroup = {
  id: string
  label?: string
  items: NavItem[]
  collapsedByDefault?: boolean
  flat?: boolean
}

/**
 * Native-first navigation: the four places you go every day, then the two
 * web-added engines. Settings is pinned separately in the shell.
 */
export const NAV_GROUPS: NavGroup[] = [
  {
    id: 'primary',
    flat: true,
    items: [
      { to: '/today', label: 'Today', icon: 'home' },
      { to: '/life', label: 'Life', icon: 'layers', matchPrefix: '/life' },
      { to: '/chat', label: 'Chat', icon: 'message-square' },
      { to: '/memory', label: 'Memory', icon: 'brain', matchPrefix: '/memory' },
    ],
  },
  {
    id: 'added',
    label: 'More',
    items: [
      { to: '/finance', label: 'Finance', icon: 'landmark' },
      { to: '/travel/plan', label: 'Travel', icon: 'navigation', matchPrefix: '/travel' },
    ],
  },
]

export const SETTINGS_NAV_ITEM: NavItem = {
  to: '/settings',
  label: 'Settings',
  icon: 'settings',
  matchPrefix: '/settings',
}

/** Flat list of every navigable item (for the command palette/breadcrumbs). */
export const ALL_NAV_ITEMS: NavItem[] = [...NAV_GROUPS.flatMap((g) => g.items), SETTINGS_NAV_ITEM]

export type LegacyRedirect = { from: string; to: string; prefix?: boolean }

/**
 * Old console routes. The landing still links to /home, so it redirects here
 * rather than requiring a landing change. Query strings are preserved by
 * Navigate when included in `to`.
 */
export const LEGACY_REDIRECTS: LegacyRedirect[] = [
  { from: '/home', to: '/today' },
  { from: '/console', to: '/today' },
  { from: '/recall-debug', to: '/today' },
  { from: '/review', to: '/today', prefix: true },
  { from: '/review-queue', to: '/today' },

  { from: '/memory/units', to: '/settings/advanced/raw?table=memory_unit' },
  { from: '/memory/facts', to: '/settings/advanced/raw?table=memory_unit' },
  { from: '/facts', to: '/settings/advanced/raw?table=memory_unit' },
  { from: '/memory/entities', to: '/settings/advanced/raw?table=entity' },
  { from: '/entities', to: '/settings/advanced/raw?table=entity' },
  { from: '/knowledge/entities', to: '/settings/advanced/raw?table=entity' },
  { from: '/memory/mental-models', to: '/settings/advanced/raw?table=mental_model' },
  { from: '/emus', to: '/memory' },
  { from: '/episodes', to: '/memory' },
  { from: '/events', to: '/life', prefix: true },
  { from: '/memory/events', to: '/memory' },

  // Routines and reminders were retired with the clean-slate engine: a routine is a repeating task, a reminder is a
  // task with an alert, and both live with the other tasks and events.
  { from: '/goals', to: '/life', prefix: true },
  { from: '/routines', to: '/life', prefix: true },
  { from: '/reminders', to: '/life', prefix: true },
  { from: '/memory/episodes', to: '/memory' },
  { from: '/graph', to: '/memory' },
  { from: '/knowledge', to: '/memory', prefix: true },
  { from: '/knowledge/graph', to: '/memory' },
  { from: '/knowledge/facts', to: '/memory' },

  { from: '/connections', to: '/settings/connections', prefix: true },
  { from: '/metrics', to: '/settings/advanced/health' },
  { from: '/ops', to: '/settings/advanced/health' },
  { from: '/connections/services', to: '/settings/advanced/health' },
  { from: '/audit', to: '/settings/advanced/activity' },
  { from: '/advanced/audit', to: '/settings/advanced/activity' },
  { from: '/raw', to: '/settings/advanced/raw' },
  { from: '/advanced/raw', to: '/settings/advanced/raw' },
  { from: '/budget', to: '/settings/advanced/usage' },

  { from: '/settings/profile', to: '/settings/account' },
  { from: '/settings/personas', to: '/settings/agents' },
  { from: '/settings/api-keys', to: '/settings/advanced/api-keys' },
]

export function isNavActive(pathname: string, item: NavItem): boolean {
  if (item.matchPrefix) {
    return pathname === item.to || pathname.startsWith(`${item.matchPrefix}/`)
  }
  return pathname === item.to
}
