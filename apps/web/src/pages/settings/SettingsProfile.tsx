import { Link, useNavigate } from 'react-router-dom'
import { ChevronLeft, ChevronRight, Shield, UserRound } from 'lucide-react'
import { useExplorerAuth } from '../../auth/context'
import { Button, useConfirm } from '../../components/ui'
import Screen from '../../components/mission/Screen'
import ListCard, { ListRow } from '../../components/mission/ListCard'

const API_HOST = (() => {
  const raw = import.meta.env.VITE_API_BASE_URL as string | undefined
  if (!raw) return 'local dev proxy'
  try {
    return new URL(raw).host
  } catch {
    return raw
  }
})()

export default function SettingsProfile() {
  const { sessionLabel, signOutExplorer, userId } = useExplorerAuth()
  const navigate = useNavigate()
  const confirm = useConfirm()

  const onSignOut = async () => {
    if (
      await confirm({
        title: 'Sign out of Mission Control?',
        body: 'This ends your session on this device.',
        confirmLabel: 'Sign out',
        tone: 'danger',
      })
    ) {
      signOutExplorer()
      navigate('/login', { replace: true })
    }
  }

  return (
    <Screen
      eyebrow={
        <Link
          to="/settings"
          className="inline-flex items-center gap-1 text-flat-muted-fg hover:text-flat-foreground"
        >
          <ChevronLeft className="size-3.5" aria-hidden />
          Settings
        </Link>
      }
      title="Account"
      description="Who you are signed in as, and how this console reaches your workspace."
    >
      <div className="flex flex-col gap-4">
        <ListCard>
          <ListRow>
            <span className="grid size-9 shrink-0 place-items-center rounded-[11px] bg-flat-tint text-flat-primary">
              <UserRound className="size-4" aria-hidden />
            </span>
            <span className="min-w-0 flex-1">
              <span className="block text-2xs text-flat-muted-fg">Signed in as</span>
              <span className="block truncate text-native-callout text-flat-foreground">
                {sessionLabel || '—'}
              </span>
            </span>
          </ListRow>
          {userId && (
            <ListRow>
              <span className="min-w-0 flex-1">
                <span className="block text-2xs text-flat-muted-fg">User ID</span>
                <span className="block truncate font-mono text-sm text-flat-foreground">
                  {userId}
                </span>
              </span>
            </ListRow>
          )}
          <ListRow>
            <span className="min-w-0 flex-1">
              <span className="block text-2xs text-flat-muted-fg">Workspace host</span>
              <span className="block truncate font-mono text-sm text-flat-foreground">
                {API_HOST}
              </span>
            </span>
          </ListRow>
        </ListCard>

        <ListCard>
          <ListRow className="transition-colors hover:bg-flat-tint-soft">
            <Link
              to="/privacy"
              className="flex min-h-11 w-full items-center gap-3 no-underline hover:no-underline"
            >
              <span className="grid size-9 shrink-0 place-items-center rounded-[11px] bg-flat-muted text-flat-muted-fg">
                <Shield className="size-4" aria-hidden />
              </span>
              <span className="min-w-0 flex-1">
                <span className="block text-native-callout font-medium text-flat-foreground">
                  Privacy
                </span>
                <span className="block truncate text-sm text-flat-muted-fg">
                  How your data works
                </span>
              </span>
              <ChevronRight className="size-4 shrink-0 text-flat-subtle-fg" aria-hidden />
            </Link>
          </ListRow>
          <ListRow>
            <span className="min-w-0 flex-1 text-sm text-flat-muted-fg">
              Exporting or deleting your memories isn’t available on the web yet.
            </span>
          </ListRow>
        </ListCard>

        <Button
          variant="ghost"
          size="touch"
          className="self-start text-flat-danger"
          onClick={() => void onSignOut()}
        >
          Sign out
        </Button>
      </div>
    </Screen>
  )
}
