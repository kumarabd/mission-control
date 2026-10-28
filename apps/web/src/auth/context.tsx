import { createContext, useContext } from 'react'
import { API_KEY_STORAGE_KEY, TOKEN_STORAGE_KEY } from './storage'

export type AuthContextValue = {
 clerkEnabled: boolean
 signedIn: boolean
 explorerReady: boolean
 // True when the signed-in user's active Clerk organization has no
 // tenant_registry row yet (api.ts's isNoTenantError) — distinct from a
 // real failure: the session/token is fine, there's just no workspace to
 // route to. ClerkProtected redirects here instead of looping on a loading
 // skeleton; src/pages/NewWorkspace.tsx is what it redirects to.
 needsWorkspace: boolean
 userId: string | null
 sessionLabel: string
 refreshExplorerToken: () => Promise<void>
 signOutExplorer: () => void
}

export const AuthContext = createContext<AuthContextValue | null>(null)

export function useExplorerAuth(): AuthContextValue {
 const ctx = useContext(AuthContext)
 if (!ctx) {
 throw new Error('useExplorerAuth must be used within AuthProvider')
 }
 return ctx
}

export function hasExplorerCredentials(): boolean {
 return Boolean(
 localStorage.getItem(TOKEN_STORAGE_KEY)?.trim() ||
 localStorage.getItem(API_KEY_STORAGE_KEY)?.trim(),
 )
}
