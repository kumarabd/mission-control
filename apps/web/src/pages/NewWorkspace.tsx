// Self-serve tenant onboarding form + progress
// (agent-harness's docs/components/gateway/web.md Phase 3). Reachable as a
// top-level route (src/App.tsx's "/setup", outside ProtectedRoute) since a
// brand-new signup has no workspace yet — AuthProvider.tsx's ClerkProtected
// redirects here the moment the router answers a proxied call with 404
// {"error":"no_tenant"} (api.ts's isNoTenantError), which is exactly the
// state a user with no provisioned tenant is in.
//
// 2026-09-25: no "workspace name" field — the tenant slug is derived
// entirely from the signed-in user's own Clerk id
// (agent-harness/workflows/internal/tenantid.SlugForSub), never chosen, so
// there's nothing to name here and nothing to switch into on completion
// (no Clerk Organization involved at all anymore).
import { useAuth } from '@clerk/clerk-react'
import { useMutation } from '@tanstack/react-query'
import { useCallback, useState } from 'react'
import { Navigate, useNavigate } from 'react-router-dom'
import { EmptyState, PageHeader, toast } from '../components/ui'
import { AuthHeader } from '../components/AuthShell'
import { clerkEnabled } from '../auth/clerk'
import { useExplorerAuth } from '../auth/context'
import { submitOnboarding } from '../lib/onboarding'
import { Provisioning } from '../features/onboarding/Provisioning'
import { Wizard } from '../features/onboarding/Wizard'
import { buildSubmission, newWizardState, type WizardState } from '../features/onboarding/model'

const SUBMITTED_STORAGE_KEY = 'onboarding.submitted'

type TokenGetter = () => Promise<string | null>

/** The setup form: a short wizard (Intelligence, Security, Memory, Review) that ends by creating the workspace. */
function WorkspaceForm({ getToken, onSubmitted }: { getToken: TokenGetter; onSubmitted: () => void }) {
  const [state, setState] = useState<WizardState>(newWizardState)
  const submit = useMutation({
    mutationFn: () => submitOnboarding(getToken, buildSubmission(state)),
    onSuccess: () => {
      localStorage.setItem(SUBMITTED_STORAGE_KEY, 'true')
      onSubmitted()
    },
    onError: (err: unknown) => {
      toast.error(err instanceof Error ? err.message : 'Could not submit the request. Try again.')
    },
  })
  return <Wizard state={state} setState={setState} submitting={submit.isPending} onSubmit={() => submit.mutate()} />
}

export default function NewWorkspace() {
  const { isLoaded, isSignedIn, getToken } = useAuth()
  const { explorerReady, refreshExplorerToken } = useExplorerAuth()
  const navigate = useNavigate()
  const tokenGetter = useCallback(() => getToken(), [getToken])
  const [submitted, setSubmitted] = useState(() => localStorage.getItem(SUBMITTED_STORAGE_KEY) === 'true')
  // The form starts fresh each time (credentials freshly generated) after a failed attempt.
  const [attempt, setAttempt] = useState(0)

  const finish = useCallback(async () => {
    try {
      await refreshExplorerToken()
    } catch {
      // Best-effort — ClerkProtected resolves the right state on its own the next time it renders.
    } finally {
      localStorage.removeItem(SUBMITTED_STORAGE_KEY)
      navigate('/today', { replace: true })
    }
  }, [refreshExplorerToken, navigate])

  if (!clerkEnabled) {
    return <EmptyState title="Sign-in is required" body="Workspace setup needs a signed-in account." />
  }
  if (!isLoaded) {
    return <p className="text-sm text-flat-muted-fg">Loading…</p>
  }
  if (!isSignedIn) {
    return <Navigate to="/login" replace />
  }
  if (explorerReady && !submitted) {
    return (
      <div className="mx-auto max-w-2xl">
        <EmptyState title="You already have a workspace" body="Your account is already connected to a workspace." action={{ label: 'Go to your workspace', to: '/today' }} />
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-flat-background text-flat-foreground">
      <AuthHeader />
      <div className="mx-auto max-w-xl space-y-8 px-5 pb-24 pt-6">
        {submitted ? (
          <Provisioning
            getToken={tokenGetter}
            onDone={finish}
            onReset={() => {
              localStorage.removeItem(SUBMITTED_STORAGE_KEY)
              setAttempt((n) => n + 1)
              setSubmitted(false)
            }}
          />
        ) : (
          <>
            <PageHeader title="Create your workspace" description="Set up your own private space, with its own memory, tools and AI models." />
            <WorkspaceForm key={attempt} getToken={tokenGetter} onSubmitted={() => setSubmitted(true)} />
          </>
        )}
      </div>
    </div>
  )
}
