import { SignUp } from '@clerk/clerk-react'
import { Navigate } from 'react-router-dom'
import { clerkAppearance, clerkEnabled } from '../auth/clerk'
import { useExplorerAuth } from '../auth/context'
import AuthShell from '../components/AuthShell'
import { useTheme } from '../theme/theme-context'

export default function SignUpPage() {
  const { theme } = useTheme()
  const { explorerReady } = useExplorerAuth()

  if (!clerkEnabled) {
    return <Navigate to="/login" replace />
  }
  if (explorerReady) {
    return <Navigate to="/today" replace />
  }

  return (
    <AuthShell title="Create your account." description="Your personal companion starts here. Create your account, then set up your space.">
      <SignUp
        routing="path"
        path="/signup"
        signInUrl="/login"
        fallbackRedirectUrl="/today"
        forceRedirectUrl="/today"
        appearance={clerkAppearance(theme)}
      />
    </AuthShell>
  )
}
