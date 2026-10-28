import { Link, useNavigate } from 'react-router-dom'
import { useState } from 'react'
import {
  Bell,
  ChevronRight,
  Cpu,
  Fingerprint,
  Link2,
  Mic,
  Shield,
  SlidersHorizontal,
  UserRound,
  UsersRound,
  Wrench,
} from 'lucide-react'
import { useExplorerAuth } from '../auth/context'
import { toast, useConfirm, Switch } from '../components/ui'
import { useAppLock } from '../app-lock/appLockContext'
import Screen from '../components/mission/Screen'
import ListCard, { ListRow } from '../components/mission/ListCard'

const ROWS = [
  { to: '/settings/account', label: 'Account', detail: 'Profile and sign out', icon: UserRound },
  { to: '/settings/agents', label: 'Agents', detail: 'Names, instructions and memory', icon: UsersRound },
  { to: '/settings/models', label: 'Models', detail: 'Platform or your own models', icon: Cpu },
  { to: '/settings/connections', label: 'Connections', detail: 'Apps your assistant can use', icon: Link2 },
  { to: '/settings/appearance', label: 'Voice and appearance', detail: 'Theme and voice', icon: Mic },
  { to: '/notifications', label: 'Notifications', detail: 'What your assistant sent', icon: Bell },
  { to: '/settings/advanced', label: 'Advanced', detail: 'Activity, health and raw tables', icon: Wrench },
]

export default function SettingsHome() {
  const navigate = useNavigate()
  const confirm = useConfirm()
  const { sessionLabel, signOutExplorer } = useExplorerAuth()
  const lock = useAppLock()
  const [lockError, setLockError] = useState<string | null>(null)

  const toggleLock = async (next: boolean) => {
    setLockError(null)
    lock.clearError()
    try {
      await lock.setEnabled(next, sessionLabel || 'This browser')
      toast.success(next ? 'Fingerprint lock is on' : 'Fingerprint lock is off')
    } catch (error) {
      setLockError(error instanceof Error ? error.message : 'Could not change the lock.')
    }
  }

  const onSignOut = async () => {
    if (await confirm({ title: 'Sign out of Mission Control?', body: 'This ends your session on this device.', confirmLabel: 'Sign out', tone: 'danger' })) {
      signOutExplorer()
      navigate('/login', { replace: true })
    }
  }

  return (
    <Screen title="Settings" description={sessionLabel ? `Signed in as ${sessionLabel}.` : undefined}>
      <ListCard>
        {ROWS.map((row) => {
          const Icon = row.icon
          return (
            <ListRow key={row.to} className="transition-colors hover:bg-flat-tint-soft">
              <Link to={row.to} className="flex min-h-11 w-full items-center gap-3 no-underline hover:no-underline">
                <span className="grid size-9 shrink-0 place-items-center rounded-[11px] bg-flat-tint text-flat-primary">
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

      <ListCard className="mt-4">
        <ListRow>
          <span className="grid size-9 shrink-0 place-items-center rounded-[11px] bg-flat-tint text-flat-primary">
            <Fingerprint className="size-4" aria-hidden />
          </span>
          <span className="min-w-0 flex-1">
            <span className="block text-native-callout font-medium text-flat-foreground">
              Require fingerprint
            </span>
            <span className="block text-sm text-flat-muted-fg">
              {lock.supported === false
                ? 'Not available in this browser.'
                : 'Fingerprint or device passcode when you come back.'}
            </span>
            {lockError && (
              <span role="alert" className="mt-1 block text-xs text-flat-danger">
                {lockError}
              </span>
            )}
          </span>
          <Switch
            checked={lock.enabled}
            disabled={lock.busy || lock.supported === false}
            onCheckedChange={(next) => void toggleLock(next)}
          />
        </ListRow>
        <ListRow>
          <span className="grid size-9 shrink-0 place-items-center rounded-[11px] bg-flat-muted text-flat-muted-fg">
            <Shield className="size-4" aria-hidden />
          </span>
          <span className="min-w-0 flex-1">
            <span className="block text-native-callout font-medium text-flat-foreground">Privacy</span>
            <Link to="/privacy" className="text-sm text-flat-primary">
              How your data works
            </Link>
          </span>
        </ListRow>
        <ListRow>
          <button type="button" onClick={() => void onSignOut()} className="min-h-11 w-full text-left text-native-callout text-flat-danger">
            Sign out
          </button>
        </ListRow>
      </ListCard>

      <p className="mt-4 flex items-center gap-2 px-1 font-mono text-2xs uppercase tracking-[0.08em] text-flat-subtle-fg">
        <SlidersHorizontal className="size-3.5" aria-hidden /> Mission Control · web console
      </p>
    </Screen>
  )
}
