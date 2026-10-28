import { useState } from 'react'
import { NavLink, useLocation } from 'react-router-dom'
import { ChevronDown, PanelLeftClose, PanelLeftOpen } from 'lucide-react'
import { cn } from '../../lib/cn'
import { isNavActive, NAV_GROUPS, SETTINGS_NAV_ITEM, type NavGroup, type NavItem } from '../../lib/navigation'
import { NavIcon } from './navIcons'

const GROUPS_KEY = 'mission-control.sidebar.groups'
const LEGACY_GROUPS_KEY = 'brainstorm.sidebar.groups'

function readJSON<T>(key: string, fallback: T): T {
  try {
    const raw = localStorage.getItem(key)
    return raw ? (JSON.parse(raw) as T) : fallback
  } catch {
    return fallback
  }
}

function NavRow({
  item,
  collapsed,
  badge,
  onNavigate,
}: {
  item: NavItem
  collapsed: boolean
  badge?: number
  onNavigate?: () => void
}) {
  const location = useLocation()
  const active = isNavActive(location.pathname, item)
  return (
    <NavLink
      to={item.to}
      onClick={onNavigate}
      title={collapsed ? item.label : undefined}
      className={cn(
        'group/nav relative flex min-h-11 items-center gap-2.5 rounded-lg px-2.5 py-2 text-native-callout no-underline transition-colors',
        collapsed && 'justify-center px-0',
        active
          ? 'bg-flat-tint text-flat-foreground'
          : 'text-flat-muted-fg hover:bg-flat-muted hover:text-flat-foreground hover:no-underline',
        item.status === 'soon' && 'text-flat-subtle-fg',
      )}
    >
      <NavIcon name={item.icon} className={cn('size-4 shrink-0', active && 'text-flat-primary')} />
      {!collapsed && (
        <>
          <span className="min-w-0 flex-1 truncate">{item.label}</span>
          {badge != null && badge > 0 && (
            <span className="rounded-full bg-flat-warning-muted px-1.5 text-2xs font-medium tabular-nums text-flat-warning">
              {badge}
            </span>
          )}
          {item.status === 'soon' && (
            <span className="shrink-0 rounded-full border border-flat-border px-1.5 font-mono text-2xs text-flat-subtle-fg">
              soon
            </span>
          )}
        </>
      )}
    </NavLink>
  )
}

function Group({
  group,
  collapsed,
  badges,
  onNavigate,
}: {
  group: NavGroup
  collapsed: boolean
  badges: Record<string, number>
  onNavigate?: () => void
}) {
  const location = useLocation()
  const [openMap, setOpenMap] = useState<Record<string, boolean>>(() =>
    readJSON(GROUPS_KEY, readJSON(LEGACY_GROUPS_KEY, {})),
  )
  const explicit = openMap[group.id]
  const open = explicit ?? !group.collapsedByDefault
  const hasActive = group.items.some((i) => isNavActive(location.pathname, i))

  const setOpen = (v: boolean) => {
    setOpenMap((m) => {
      const next = { ...m, [group.id]: v }
      try {
        localStorage.setItem(GROUPS_KEY, JSON.stringify(next))
      } catch {
        /* ignore */
      }
      return next
    })
  }

  const rows = (
    <div className="flex flex-col gap-0.5">
      {group.items.map((item) => (
        <NavRow
          key={item.to}
          item={item}
          collapsed={collapsed}
          badge={item.badgeKey ? badges[item.badgeKey] : undefined}
          onNavigate={onNavigate}
        />
      ))}
    </div>
  )

  if (group.flat || collapsed) {
    return <div className="flex flex-col gap-0.5">{rows}</div>
  }

  return (
    <div>
      {group.collapsedByDefault ? (
        <button
          type="button"
          onClick={() => setOpen(!open)}
          className="flex w-full items-center justify-between px-2 py-1 font-mono text-2xs text-flat-subtle-fg hover:text-flat-muted-fg"
        >
          <span>{group.label}</span>
          <ChevronDown className={cn('size-3 transition-transform', !open && '-rotate-90')} />
        </button>
      ) : (
        <p className="px-2 py-1 font-mono text-2xs text-flat-subtle-fg">{group.label}</p>
      )}
      {open ? (
        <div className="mt-0.5">{rows}</div>
      ) : (
        hasActive && <p className="px-2 text-2xs text-flat-subtle-fg">Contains current page</p>
      )}
    </div>
  )
}

export default function SideNav({
  collapsed = false,
  onToggleCollapsed,
  badges = {},
  onNavigate,
  mobile = false,
}: {
  collapsed?: boolean
  onToggleCollapsed?: () => void
  badges?: Record<string, number>
  onNavigate?: () => void
  mobile?: boolean
}) {
  return (
    <nav
      className={cn(
        'flex h-full flex-col border-r border-flat-border bg-flat-tint-soft',
        collapsed ? 'w-14' : 'w-60',
      )}
    >
      <div
        className={cn(
          'flex h-14 shrink-0 items-center border-b border-flat-border px-3',
          collapsed && 'justify-center px-0',
        )}
      >
        <NavLink to="/today" onClick={onNavigate} className="flex items-center gap-2.5 no-underline hover:no-underline">
          <img src="/logo-mark.svg" alt="" className="size-5 shrink-0" draggable={false} />
          {!collapsed && (
            <span className="text-lg font-semibold tracking-tight text-flat-foreground">Mission Control</span>
          )}
        </NavLink>
      </div>

      <div className="flex-1 space-y-4 overflow-y-auto px-2 py-3">
        {NAV_GROUPS.map((group) => (
          <Group key={group.id} group={group} collapsed={collapsed} badges={badges} onNavigate={onNavigate} />
        ))}
      </div>

      <div className="shrink-0 border-t border-flat-border p-2">
        <NavRow item={SETTINGS_NAV_ITEM} collapsed={collapsed} onNavigate={onNavigate} />
        {!mobile && onToggleCollapsed && (
          <button
            type="button"
            onClick={onToggleCollapsed}
            className={cn(
              'mt-0.5 flex min-h-11 w-full items-center gap-2 rounded-lg px-2.5 py-2 text-sm text-flat-muted-fg hover:bg-flat-muted hover:text-flat-foreground',
              collapsed && 'justify-center px-0',
            )}
            aria-label={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
          >
            {collapsed ? <PanelLeftOpen className="size-4" /> : <PanelLeftClose className="size-4" />}
            {!collapsed && <span>Collapse</span>}
          </button>
        )}
      </div>
    </nav>
  )
}
