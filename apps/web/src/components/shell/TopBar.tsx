import { Bell, Moon, Search, Settings, Sun } from 'lucide-react'
import { useLocation, useNavigate } from 'react-router-dom'
import { useExplorerAuth } from '../../auth/context'
import { useTheme } from '../../theme/theme-context'
import { useNotificationUnread } from '../../lib/notifications'
import { Breadcrumbs, IconButton, Kbd, Menu } from '../ui'
import { useConfirm } from '../ui/Dialog'
import { crumbsFromPath } from './breadcrumbs'

export default function TopBar({ onOpenCommand }: { onOpenCommand: () => void }) {
  const location = useLocation()
  const navigate = useNavigate()
  const { theme, toggleTheme } = useTheme()
  const { sessionLabel, signOutExplorer } = useExplorerAuth()
  const { data: unread = 0 } = useNotificationUnread()
  const confirm = useConfirm()
  const crumbs = crumbsFromPath(location.pathname)

  const onSignOut = async () => {
    if (await confirm({ title: 'Sign out?', body: 'This ends your session on this device.', confirmLabel: 'Sign out', tone: 'danger' })) {
      signOutExplorer()
      navigate('/login', { replace: true })
    }
  }

  return (
    <header className="flex h-14 shrink-0 items-center gap-3 border-b border-flat-border bg-flat-background px-3 sm:px-6">
      <Breadcrumbs items={crumbs} className="min-w-0 flex-1" />

      <button
        type="button"
        onClick={onOpenCommand}
        className="hidden h-9 min-w-60 items-center gap-2.5 rounded-full border border-flat-border bg-flat-tint-soft px-3.5 text-sm text-flat-muted-fg transition-colors hover:border-flat-primary sm:flex"
      >
        <Search className="size-3.5" />
        <span>Search or ask…</span>
        <Kbd className="ml-auto">⌘K</Kbd>
      </button>
      <IconButton label="Search" className="sm:hidden" onClick={onOpenCommand}>
        <Search />
      </IconButton>

      <IconButton
        label={unread > 0 ? `Notifications, ${unread} unread` : 'Notifications'}
        size="lg"
        className="relative"
        onClick={() => navigate('/notifications')}
      >
        <Bell aria-hidden />
        {unread > 0 && (
          <span
            aria-hidden
            className="absolute right-1 top-1 min-w-4 rounded-full bg-flat-primary px-1 text-center font-mono text-[10px] leading-4 text-flat-on-accent"
          >
            {unread > 9 ? '9+' : unread}
          </span>
        )}
      </IconButton>

      <IconButton label="Settings" size="lg" className="max-sm:hidden" onClick={() => navigate('/settings')}>
        <Settings aria-hidden />
      </IconButton>

      <IconButton label={theme === 'dark' ? 'Switch to light' : 'Switch to dark'} size="lg" className="max-sm:hidden" onClick={toggleTheme}>
        {theme === 'dark' ? <Sun /> : <Moon />}
      </IconButton>

      <Menu
        trigger={
          <button
            type="button"
            aria-label="Account"
            className="grid size-8 place-items-center rounded-full bg-flat-tint text-sm font-semibold text-flat-primary transition-transform hover:scale-105"
          >
            {(sessionLabel || 'A').trim().charAt(0).toUpperCase()}
          </button>
        }
        items={[
          { type: 'label', label: sessionLabel || 'Signed in' },
          { id: 'settings', label: 'Settings', href: '/settings' },
          { id: 'appearance', label: 'Appearance', href: '/settings/appearance' },
          {
            id: 'theme',
            label: theme === 'dark' ? 'Switch to light' : 'Switch to dark',
            icon: theme === 'dark' ? <Sun /> : <Moon />,
            onSelect: toggleTheme,
          },
          { type: 'separator' },
          { id: 'signout', label: 'Sign out', tone: 'danger', onSelect: onSignOut },
        ]}
      />
    </header>
  )
}
