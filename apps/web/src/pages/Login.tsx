import { SignIn } from '@clerk/clerk-react'
import type { FormEvent } from 'react'
import { useState } from 'react'
import { Navigate } from 'react-router-dom'
import { clerkAppearance, clerkEnabled } from '../auth/clerk'
import { useExplorerAuth } from '../auth/context'
import {
  AGENT_ID_STORAGE_KEY,
  API_KEY_STORAGE_KEY,
  DEFAULT_AGENT_ID,
  TOKEN_STORAGE_KEY,
} from '../lib/api'
import AuthShell from '../components/AuthShell'
import { useTheme } from '../theme/theme-context'
import Button from '../components/ui/Button'
import Input from '../components/ui/Input'

export default function Login() {
  const { theme } = useTheme()
  const { explorerReady, clerkEnabled: clerkOn } = useExplorerAuth()
  const [token, setToken] = useState(localStorage.getItem(TOKEN_STORAGE_KEY) || '')
  const [apiKey, setApiKey] = useState(localStorage.getItem(API_KEY_STORAGE_KEY) || '')
  const [agentId, setAgentId] = useState(
    localStorage.getItem(AGENT_ID_STORAGE_KEY) || DEFAULT_AGENT_ID,
  )

  // With Clerk enabled the user landing here means their Clerk session is
  // absent — a stale localStorage token must not bounce them back into a
  // protected route, creating an infinite redirect loop.
  if (explorerReady && !clerkOn) {
    return <Navigate to="/today" replace />
  }

  const onLegacySave = (e: FormEvent) => {
    e.preventDefault()
    localStorage.setItem(TOKEN_STORAGE_KEY, token.trim())
    localStorage.setItem(API_KEY_STORAGE_KEY, apiKey.trim())
    localStorage.setItem(AGENT_ID_STORAGE_KEY, agentId.trim() || DEFAULT_AGENT_ID)
    window.location.href = '/today'
  }

  if (clerkEnabled) {
    return (
      <AuthShell title="Welcome back." description="Sign in to see what your assistant has been up to.">
        <SignIn
          routing="path"
          path="/login"
          signUpUrl="/signup"
          fallbackRedirectUrl="/today"
          forceRedirectUrl="/today"
          appearance={clerkAppearance(theme)}
        />
      </AuthShell>
    )
  }

  return (
    <AuthShell title="Sign in" description="Local development sign-in. Paste an API key or token from your operator.">
      <form className="w-full space-y-4 rounded-2xl border border-flat-border bg-flat-surface p-6 text-left" onSubmit={onLegacySave}>
        <label className="block text-sm font-medium">
          API key
          <Input className="mt-1.5" value={apiKey} onChange={(e) => setApiKey(e.target.value)} placeholder="dev-key" />
        </label>
        <label className="block text-sm font-medium">
          Bearer token <span className="font-normal text-flat-muted-fg">(optional)</span>
          <Input className="mt-1.5" value={token} onChange={(e) => setToken(e.target.value)} />
        </label>
        <label className="block text-sm font-medium">
          Default agent ID
          <Input className="mt-1.5" value={agentId} onChange={(e) => setAgentId(e.target.value)} />
        </label>
        <Button type="submit" variant="solid" className="w-full">
          Continue
        </Button>
        <p className="text-xs text-flat-muted-fg">
          Set <code className="font-mono">VITE_CLERK_PUBLISHABLE_KEY</code> to use account sign-in instead.
        </p>
      </form>
    </AuthShell>
  )
}
