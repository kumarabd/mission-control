import type { ReactNode } from 'react'
import {
  useCallback,
  useEffect,
  useMemo,
  useState,
} from 'react'
import { useNavigate } from 'react-router-dom'
import { Fingerprint, LogOut } from 'lucide-react'
import { Button } from '../components/ui'
import { GemMark } from '../features/onboarding/GemMark'
import { useExplorerAuth } from '../auth/context'
import {
  appLockCredentialId,
  clearAppLockStorage,
  isAppLockEnabled,
  platformAuthenticatorAvailable,
  registerAppLock,
  verifyAppLock,
} from '../lib/appLock'
import { AppLockContext } from './appLockContext'

function messageOf(error: unknown): string {
  if (error instanceof DOMException && error.name === 'NotAllowedError') {
    return 'Fingerprint wasn’t confirmed. Try again.'
  }
  return error instanceof Error ? error.message : 'Could not use the fingerprint lock.'
}

export function AppLockProvider({ children }: { children: ReactNode }) {
  const navigate = useNavigate()
  const { sessionLabel, signOutExplorer } = useExplorerAuth()
  const [enabled, setEnabledState] = useState(() => isAppLockEnabled())
  const [locked, setLocked] = useState(() => isAppLockEnabled())
  const [supported, setSupported] = useState<boolean | null>(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false
    void platformAuthenticatorAvailable().then((available) => {
      if (!cancelled) setSupported(available)
    })
    return () => {
      cancelled = true
    }
  }, [])

  // Coming back to the tab after a moment asks for the fingerprint again,
  // matching the native app’s lock-on-background behaviour.
  useEffect(() => {
    if (!enabled) return
    let hiddenAt = 0
    const onVisibility = () => {
      if (document.visibilityState === 'hidden') {
        hiddenAt = Date.now()
        return
      }
      if (hiddenAt && Date.now() - hiddenAt > 3000) setLocked(true)
      hiddenAt = 0
    }
    document.addEventListener('visibilitychange', onVisibility)
    return () => document.removeEventListener('visibilitychange', onVisibility)
  }, [enabled])

  const setEnabled = useCallback(async (next: boolean, label: string) => {
    setBusy(true)
    setError(null)
    try {
      if (next) {
        await registerAppLock(label)
        setEnabledState(true)
        setLocked(false)
      } else {
        clearAppLockStorage()
        setEnabledState(false)
        setLocked(false)
      }
    } catch (cause) {
      setError(messageOf(cause))
      throw cause
    } finally {
      setBusy(false)
    }
  }, [])

  const unlock = useCallback(async () => {
    if (!appLockCredentialId()) {
      clearAppLockStorage()
      setEnabledState(false)
      setLocked(false)
      setError('The saved lock was missing. Set it up again in Settings.')
      return
    }
    setBusy(true)
    setError(null)
    try {
      if (await verifyAppLock()) {
        setLocked(false)
      } else {
        setError('Fingerprint wasn’t confirmed. Try again.')
      }
    } catch (cause) {
      setError(messageOf(cause))
    } finally {
      setBusy(false)
    }
  }, [])

  const value = useMemo(
    () => ({
      enabled,
      supported,
      busy,
      error,
      setEnabled,
      clearError: () => setError(null),
    }),
    [enabled, supported, busy, error, setEnabled],
  )

  return (
    <AppLockContext.Provider value={value}>
      {children}
      {locked && (
        <div
          role="dialog"
          aria-modal="true"
          aria-labelledby="app-lock-title"
          className="fixed inset-0 z-[120] grid place-items-center overflow-y-auto bg-flat-background p-6"
        >
          <div className="flex w-full max-w-sm flex-col items-center text-center">
            <GemMark className="w-20" />
            <h1 id="app-lock-title" className="mt-6 text-native-headline text-flat-foreground">
              Mission Control is locked
            </h1>
            <p className="mt-2 text-native-callout text-flat-muted-fg">
              Unlock with your fingerprint or device passcode to continue.
            </p>

            {error && (
              <p
                role="alert"
                className="mt-4 w-full rounded-md border border-flat-warning/30 bg-flat-warning-muted px-3 py-2 text-sm text-flat-foreground"
              >
                {error}
              </p>
            )}

            {supported === false ? (
              <p className="mt-4 text-sm text-flat-muted-fg">
                This browser doesn’t offer a fingerprint or device passcode. Turn the lock off
                to continue on this device.
              </p>
            ) : null}

            <div className="mt-6 flex w-full flex-col gap-2">
              {supported !== false && (
                <Button
                  variant="primary"
                  size="touch"
                  className="focus:outline-none"
                  loading={busy}
                  onClick={() => void unlock()}
                  iconLeft={<Fingerprint className="size-5" aria-hidden />}
                  autoFocus
                >
                  Unlock with fingerprint
                </Button>
              )}
              {supported === false && (
                <Button
                  variant="secondary"
                  size="touch"
                  disabled={busy}
                  onClick={() => void setEnabled(false, sessionLabel || 'This browser')}
                >
                  Turn off the lock
                </Button>
              )}
              <Button
                variant="ghost"
                size="touch"
                disabled={busy}
                iconLeft={<LogOut className="size-4" aria-hidden />}
                onClick={() => {
                  signOutExplorer()
                  navigate('/login', { replace: true })
                }}
              >
                Sign out
              </Button>
            </div>

            <p className="mt-5 text-2xs text-flat-subtle-fg">
              This locks this browser. It doesn’t replace your sign-in.
            </p>
          </div>
        </div>
      )}
    </AppLockContext.Provider>
  )
}
