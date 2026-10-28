import { useEffect } from 'react'
import { Command } from 'cmdk'
import { useNavigate } from 'react-router-dom'
import { Moon, Search, Settings, Sun } from 'lucide-react'
import { NAV_GROUPS } from '../../lib/navigation'
import { useTheme } from '../../theme/theme-context'
import { NavIcon } from './navIcons'

export default function CommandPalette({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const navigate = useNavigate()
  const { theme, setTheme } = useTheme()

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault()
        onOpenChange(!open)
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [open, onOpenChange])

  const go = (to: string) => {
    onOpenChange(false)
    navigate(to)
  }

  if (!open) return null

  return (
    <div
      className="fixed inset-0 z-[60] flex items-start justify-center bg-[var(--theme-scrim)] p-4 pt-[12vh]"
      onClick={() => onOpenChange(false)}
    >
      <Command
        label="Command palette"
        className="w-full max-w-lg overflow-hidden rounded-lg border border-flat-border bg-flat-surface shadow-3"
        onClick={(e) => e.stopPropagation()}
        loop
      >
        <div className="flex items-center gap-2 border-b border-flat-border px-3">
          <Search className="size-4 shrink-0 text-flat-subtle-fg" />
          <Command.Input
            autoFocus
            placeholder="Go to…"
            className="h-11 w-full bg-transparent text-base text-flat-foreground outline-none placeholder:text-flat-subtle-fg"
          />
        </div>
        <Command.List className="max-h-80 overflow-y-auto p-1.5">
          <Command.Empty className="px-3 py-6 text-center text-sm text-flat-muted-fg">
            No matches.
          </Command.Empty>
          {NAV_GROUPS.map((group) => (
            <Command.Group
              key={group.id}
              heading={group.label}
              className="[&_[cmdk-group-heading]]:px-2 [&_[cmdk-group-heading]]:py-1 [&_[cmdk-group-heading]]:text-2xs [&_[cmdk-group-heading]]:text-flat-subtle-fg"
            >
              {group.items.map((item) => (
                <Command.Item
                  key={item.to}
                  value={`${item.label} ${item.to}`}
                  onSelect={() => go(item.to)}
                  className="flex cursor-pointer items-center gap-2.5 rounded-sm px-2 py-2 text-base text-flat-foreground data-[selected=true]:bg-flat-muted"
                >
                  <NavIcon name={item.icon} className="size-4 text-flat-muted-fg" />
                  <span className="flex-1">{item.label}</span>
                  {item.status === 'soon' && <span className="text-2xs text-flat-subtle-fg">soon</span>}
                </Command.Item>
              ))}
            </Command.Group>
          ))}
          <Command.Group
            heading="Preferences"
            className="[&_[cmdk-group-heading]]:px-2 [&_[cmdk-group-heading]]:py-1 [&_[cmdk-group-heading]]:text-2xs [&_[cmdk-group-heading]]:text-flat-subtle-fg"
          >
            <Command.Item
              value="settings"
              onSelect={() => go('/settings')}
              className="flex cursor-pointer items-center gap-2.5 rounded-sm px-2 py-2 text-base text-flat-foreground data-[selected=true]:bg-flat-muted"
            >
              <Settings className="size-4 text-flat-muted-fg" />
              <span className="flex-1">Settings</span>
            </Command.Item>
            {(['light', 'dark'] as const).map((t) => (
              <Command.Item
                key={t}
                value={`theme ${t}`}
                onSelect={() => {
                  setTheme(t)
                  onOpenChange(false)
                }}
                className="flex cursor-pointer items-center gap-2.5 rounded-sm px-2 py-2 text-base text-flat-foreground data-[selected=true]:bg-flat-muted"
              >
                {t === 'light' ? (
                  <Sun className="size-4 text-flat-muted-fg" />
                ) : (
                  <Moon className="size-4 text-flat-muted-fg" />
                )}
                <span className="flex-1">Theme: {t}</span>
                {theme === t && <span className="text-2xs text-flat-primary">current</span>}
              </Command.Item>
            ))}
          </Command.Group>
        </Command.List>
      </Command>
    </div>
  )
}
