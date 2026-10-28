import type { ReactNode } from 'react'
import { ClerkProvider } from '@clerk/clerk-react'
import { AuthProvider } from './AuthProvider'
import { clerkEnabled } from './clerk'

const clerkKey = import.meta.env.VITE_CLERK_PUBLISHABLE_KEY?.trim() || ''

/**
 * The real auth boundary. Kept out of the public landing's eager graph so Clerk
 * and the console routes load only when someone enters the authenticated app.
 */
export function RealAuthProvider({ children }: { children: ReactNode }) {
  if (clerkEnabled && clerkKey) {
    return (
      <ClerkProvider
        publishableKey={clerkKey}
        signInUrl="/login"
        signUpUrl="/signup"
        signInFallbackRedirectUrl="/today"
        signUpFallbackRedirectUrl="/today"
      >
        <AuthProvider>{children}</AuthProvider>
      </ClerkProvider>
    )
  }
  return <AuthProvider>{children}</AuthProvider>
}
