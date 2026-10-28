import { useAuth, useUser } from '@clerk/clerk-react'
import type { ReactNode } from 'react'
import { useCallback, useEffect, useMemo, useState } from 'react'
import { Navigate, useLocation } from 'react-router-dom'
import AppSkeleton from '../components/shell/AppSkeleton'
import {
  API_KEY_STORAGE_KEY,
  TOKEN_STORAGE_KEY,
  getMe,
  isNoTenantError,
  setClerkTokenGetter,
  setUnauthorizedHandler,
} from '../lib/api'
import { clerkEnabled } from './clerk'
import { fixtureEnabled } from '../lib/devFixture'
import { resolveSessionLabel } from './sessionLabel'
import { AuthContext, hasExplorerCredentials, useExplorerAuth } from './context'

function AuthProviderInner({ children }: { children: ReactNode }) {
  const { isLoaded, isSignedIn, getToken, signOut: clerkSignOut } = useAuth()
  const { user } = useUser()
  const [explorerReady, setExplorerReady] = useState(false)
  const [needsWorkspace, setNeedsWorkspace] = useState(false)
  const [userId, setUserId] = useState<string | null>(null)

  // Registers the live Clerk token as the bearer api.ts's authHeaders()
  // sends on every router-proxied call. 2026-09-26: there is no separate
  // explorer session to exchange or store anymore — agent-brain trusts the
  // shared router's own verified identity instead of minting its own
  // session token, so the one credential that ever needs to reach it is
  // this one, fetched fresh per request (getToken() caches/refreshes
  // internally; cheap to call every time).
  useEffect(() => {
    if (!isSignedIn) {
      setClerkTokenGetter(null)
      return
    }
    setClerkTokenGetter(() => getToken())
    return () => setClerkTokenGetter(null)
  }, [isSignedIn, getToken])

  // refreshExplorerToken's name is a holdover for NewWorkspace.tsx and
  // context.tsx's existing "recheck whether we're ready yet" call site — it
  // no longer refreshes a token at all, just re-probes readiness via getMe().
  const refreshExplorerToken = useCallback(async () => {
    if (!isSignedIn) {
      return
    }
    try {
      const me = await getMe()
      setNeedsWorkspace(false)
      setUserId(me.user_id)
      setExplorerReady(true)
    } catch (err) {
      if (isNoTenantError(err)) {
        // A real, valid session — this org just has no workspace
        // provisioned yet. Not a failure to retry: ClerkProtected redirects
        // to /setup instead of looping this call.
        setNeedsWorkspace(true)
        setExplorerReady(false)
        return
      }
      throw err
    }
  }, [isSignedIn])

  useEffect(() => {
    if (!isLoaded || !isSignedIn) {
      return
    }
    let cancelled = false
    void (async () => {
      try {
        await refreshExplorerToken()
      } catch {
        if (!cancelled) {
          setExplorerReady(false)
        }
      }
    })()
    return () => {
      cancelled = true
    }
  }, [isLoaded, isSignedIn, refreshExplorerToken])

  // A 401 here no longer means "the cached token expired, go refresh it" —
  // there's nothing cached anymore, every call already sends a live Clerk
  // token. It means the backend genuinely rejected a live token, so retrying
  // the same call (refreshExplorerToken calls getMe(), which goes through
  // request(), which calls this handler again on its own 401) would loop
  // forever with no backoff. Just drop out of "ready" instead — ClerkProtected
  // falls back to a skeleton and stops rendering whatever was calling.
  useEffect(() => {
    setUnauthorizedHandler(() => {
      setExplorerReady(false)
    })
    return () => setUnauthorizedHandler(null)
  }, [])

  const signOutExplorer = useCallback(() => {
    localStorage.removeItem(TOKEN_STORAGE_KEY)
    localStorage.removeItem(API_KEY_STORAGE_KEY)
    setExplorerReady(false)
    setUserId(null)
    void clerkSignOut()
  }, [clerkSignOut])

  const sessionLabel = resolveSessionLabel({ userId, clerkUser: user })

  const value = useMemo(
    () => ({
      clerkEnabled: true,
      signedIn: Boolean(isSignedIn),
      explorerReady,
      needsWorkspace,
      userId,
      sessionLabel,
      refreshExplorerToken,
      signOutExplorer,
    }),
    [explorerReady, needsWorkspace, isSignedIn, refreshExplorerToken, sessionLabel, signOutExplorer, userId],
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

function LegacyAuthProvider({ children }: { children: ReactNode }) {
  const [explorerReady, setExplorerReady] = useState(hasExplorerCredentials)
  const [userId, setUserId] = useState<string | null>(null)

  useEffect(() => {
    setUnauthorizedHandler(() => {
      setExplorerReady(hasExplorerCredentials())
    })
    return () => setUnauthorizedHandler(null)
  }, [])

  useEffect(() => {
    if (!explorerReady) {
      return
    }
    void getMe()
      .then((me) => setUserId(me.user_id))
      .catch(() => setUserId(null))
  }, [explorerReady])

  const sessionLabel = resolveSessionLabel({ userId })

  const value = useMemo(
    () => ({
      clerkEnabled: false,
      signedIn: explorerReady,
      explorerReady,
      // No Clerk org concept in legacy (no-Clerk-key) mode — nothing to
      // route to /setup for.
      needsWorkspace: false,
      userId,
      sessionLabel,
      refreshExplorerToken: async () => {},
      signOutExplorer: () => {
        localStorage.removeItem(TOKEN_STORAGE_KEY)
        localStorage.removeItem(API_KEY_STORAGE_KEY)
        setExplorerReady(false)
        setUserId(null)
      },
    }),
    [explorerReady, sessionLabel, userId],
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function AuthProvider({ children }: { children: ReactNode }) {
  if (clerkEnabled) {
    return <AuthProviderInner>{children}</AuthProviderInner>
  }
  return <LegacyAuthProvider>{children}</LegacyAuthProvider>
}

function ClerkProtected({ children }: { children: ReactNode }) {
  const { isLoaded, isSignedIn } = useAuth()
  const { explorerReady, needsWorkspace } = useExplorerAuth()
  const location = useLocation()

  if (!isLoaded) {
    return <AppSkeleton />
  }
  if (!isSignedIn) {
    return <Navigate to="/login" state={{ from: location.pathname }} replace />
  }
  if (needsWorkspace) {
    // Real, valid session with no workspace yet — /setup is a top-level
    // route (like /login), reachable without explorerReady ever becoming
    // true, since that's exactly the state a brand-new signup is in.
    return <Navigate to="/setup" replace />
  }
  if (!explorerReady) {
    return <AppSkeleton />
  }
  return <>{children}</>
}

export function ProtectedRoute({ children }: { children: ReactNode }) {
  const { clerkEnabled: clerkOn, explorerReady } = useExplorerAuth()
  const location = useLocation()

  if (fixtureEnabled()) {
    return <>{children}</>
  }
  if (clerkOn) {
    return <ClerkProtected>{children}</ClerkProtected>
  }
  if (!explorerReady && location.pathname !== '/login') {
    return <Navigate to="/login" replace />
  }
  return <>{children}</>
}
