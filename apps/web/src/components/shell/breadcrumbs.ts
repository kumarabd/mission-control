import type { Crumb } from '../ui'
import { ALL_NAV_ITEMS } from '../../lib/navigation'

const SECTION_LABEL: Record<string, string> = {
  today: 'Today',
  home: 'Today',
  goals: 'Goals',
  routines: 'Routines',
  reminders: 'Reminders',
  chat: 'Chat',
  memory: 'Memory',
  notifications: 'Notifications',
  settings: 'Settings',
  account: 'Account',
  agents: 'Agents',
  models: 'Models',
  connections: 'Connections',
  appearance: 'Voice and appearance',
  advanced: 'Advanced',
  activity: 'Activity',
  health: 'Health',
  raw: 'Raw tables',
  'api-keys': 'API keys',
  usage: 'Usage',
  finance: 'Finance',
  travel: 'Travel',
  plan: 'Plan',
  fleet: 'Fleet',
  trips: 'Trips',
  review: 'Today',
  console: 'Today',
}

const label = (seg: string) =>
  SECTION_LABEL[seg] ?? decodeURIComponent(seg).replace(/[-_]/g, ' ').replace(/^\w/, (c) => c.toUpperCase())

/** Build breadcrumb trail from the pathname, resolving known sections. */
export function crumbsFromPath(pathname: string): Crumb[] {
  const segs = pathname.split('/').filter(Boolean)
  if (segs.length === 0) return [{ label: 'Today' }]

  const navItem = ALL_NAV_ITEMS.find(
    (i) => i.to === pathname || (i.matchPrefix && pathname.startsWith(`${i.matchPrefix}/`)),
  )

  const crumbs: Crumb[] = []
  let acc = ''
  segs.forEach((seg, i) => {
    acc += `/${seg}`
    const isLast = i === segs.length - 1
    // The last segment of a detail route (an id) keeps its raw value.
    const isDetailId = isLast && i > 0 && !SECTION_LABEL[seg] && /[0-9:]/.test(seg)
    crumbs.push({
      label: isDetailId ? seg : label(seg),
      to: isLast ? undefined : acc,
    })
  })

  // Prefer the nav item's own label for its landing route.
  if (navItem && navItem.to === pathname && crumbs.length > 0) {
    crumbs[crumbs.length - 1] = { label: navItem.label }
  }
  // A trip or vehicle id is not a name; say what it is instead.
  if (segs[0] === 'travel' && segs.length === 3) {
    crumbs[crumbs.length - 1] = { label: segs[1] === 'trips' ? 'Trip details' : decodeURIComponent(segs[2]) }
  }
  if (segs.length === 2 && ['goals', 'routines', 'reminders'].includes(segs[0])) {
    crumbs[crumbs.length - 1] = {
      label: segs[0] === 'goals' ? 'Goal' : segs[0] === 'routines' ? 'Routine' : 'Reminder',
    }
  }
  if (segs[0] === 'memory' && segs.length > 1) {
    crumbs[crumbs.length - 1] = {
      label: segs.at(-1) === 'source' ? 'Supporting memory' : 'Memory item',
    }
  }
  // "Memory › Memory": drop a parent crumb that the landing label repeats.
  if (crumbs.length > 1 && crumbs[crumbs.length - 2].label === crumbs[crumbs.length - 1].label) {
    crumbs.splice(crumbs.length - 2, 1)
  }
  return crumbs
}
