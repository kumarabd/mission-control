import { createContext, useContext } from 'react'

export type AppLockContextValue = {
  enabled: boolean
  supported: boolean | null
  busy: boolean
  error: string | null
  setEnabled: (next: boolean, label: string) => Promise<void>
  clearError: () => void
}

export const AppLockContext = createContext<AppLockContextValue | null>(null)

export function useAppLock(): AppLockContextValue {
  const value = useContext(AppLockContext)
  if (!value) throw new Error('useAppLock must be used inside AppLockProvider')
  return value
}
