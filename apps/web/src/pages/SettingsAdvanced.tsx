import { Link } from 'react-router-dom'
import { Activity, ChevronLeft, ChevronRight, Gauge, KeyRound, Table2 } from 'lucide-react'
import Screen from '../components/mission/Screen'
import ListCard, { ListRow } from '../components/mission/ListCard'

const ROWS = [
  { to: '/settings/advanced/activity', label: 'Activity', detail: 'A plain record of what your assistant did, learned and asked you.', icon: Activity },
  { to: '/settings/advanced/health', label: 'Health', detail: 'How quickly your assistant is responding right now.', icon: Gauge },
  { to: '/settings/advanced/raw', label: 'Raw tables', detail: 'Every table exactly as stored.', icon: Table2 },
  { to: '/settings/advanced/api-keys', label: 'API keys', detail: 'Connect a tool to your workspace.', icon: KeyRound },
  { to: '/settings/advanced/usage', label: 'Usage', detail: 'Cost and limits — coming soon.', icon: Gauge },
]

export default function SettingsAdvanced() {
  return (
    <Screen
      eyebrow={
        <Link to="/settings" className="inline-flex items-center gap-1 text-flat-muted-fg hover:text-flat-foreground">
          <ChevronLeft className="size-3.5" /> Settings
        </Link>
      }
      title="Advanced"
      description="Operational surfaces for looking underneath the assistant."
    >
      <ListCard>
        {ROWS.map((row) => {
          const Icon = row.icon
          return (
            <ListRow key={row.to} className="transition-colors hover:bg-flat-tint-soft">
              <Link to={row.to} className="flex min-h-11 w-full items-center gap-3 no-underline hover:no-underline">
                <span className="grid size-9 shrink-0 place-items-center rounded-[11px] bg-flat-muted text-flat-muted-fg">
                  <Icon className="size-4" aria-hidden />
                </span>
                <span className="min-w-0 flex-1">
                  <span className="block text-native-callout font-medium text-flat-foreground">{row.label}</span>
                  <span className="block truncate text-sm text-flat-muted-fg">{row.detail}</span>
                </span>
                <ChevronRight className="size-4 shrink-0 text-flat-subtle-fg" aria-hidden />
              </Link>
            </ListRow>
          )
        })}
      </ListCard>
    </Screen>
  )
}
