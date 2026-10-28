import { useAuth } from '@clerk/clerk-react'
import { useLayoutEffect, type ReactNode } from 'react'
import { clerkEnabled } from '../auth/clerk'
import { setTokenGetter } from './token'

function ClerkTokenBridge({ children }: { children: ReactNode }) {
  const { getToken } = useAuth()
  // A layout effect, not a plain one: effects run children first, so with useEffect the first queries would fire
  // before the getter is set and go out with no token (the router answers those 401).
  useLayoutEffect(() => {
    setTokenGetter(() => getToken())
    return () => setTokenGetter(null)
  }, [getToken])
  return <>{children}</>
}

/**
 * Hands the signed-in Clerk session's token to the travel API client. Without Clerk (local dev against an engine
 * directly) there is nothing to hand over and requests go out as they are.
 */
export function TravelAuth({ children }: { children: ReactNode }) {
  return clerkEnabled ? <ClerkTokenBridge>{children}</ClerkTokenBridge> : <>{children}</>
}
