import { useQuery } from '@tanstack/react-query'
import { CheckCircle2, Circle, Loader2 } from 'lucide-react'
import { useEffect, useRef } from 'react'
import { Button, EmptyState } from '../../components/ui'
import { cn } from '../../lib/cn'
import { getOnboardingStatus, type OnboardingStatus } from '../../lib/onboarding'
import { GemMark } from './GemMark'
import { progressFraction, STEP_KEYS, STEP_LABEL } from './model'
import './onboarding.css'

type TokenGetter = () => Promise<string | null>

/** Builds the workspace in view: the mark fills as the workflow's eight steps finish, then the person is let in. */
export function Provisioning({ getToken, onReset, onDone }: { getToken: TokenGetter; onReset: () => void; onDone: () => void | Promise<void> }) {
  const finishing = useRef(false)
  const query = useQuery({
    queryKey: ['onboarding-status'],
    queryFn: () => getOnboardingStatus(getToken),
    refetchInterval: (q) => {
      const status = q.state.data?.status
      return status === 'completed' || status === 'failed' ? false : 3000
    },
  })
  const data = query.data
  const status = data?.status

  useEffect(() => {
    if (status !== 'completed' || finishing.current) return
    finishing.current = true
    // A beat on the finished state before the app takes over.
    const t = window.setTimeout(() => void onDone(), 1600)
    return () => window.clearTimeout(t)
  }, [status, onDone])

  if (query.isLoading) return <p className="text-sm text-flat-muted-fg">Loading progress…</p>
  if (query.isError || !data) {
    // Not always transient (e.g. a workflow an operator terminated can't be queried), so offer the same way out as a
    // failure: resubmitting is always safe, the router starts a fresh execution once the old one is closed.
    return (
      <div className="space-y-3">
        <EmptyState title="Couldn't load progress" body="Something went wrong checking your workspace's setup status." />
        <Button size="sm" onClick={onReset}>Back to review</Button>
      </div>
    )
  }

  return <ProvisioningView data={data} onReset={onReset} />
}

/** The progress screen itself, with no data fetching, so it can be previewed and tested on its own. */
export function ProvisioningView({ data, onReset }: { data: OnboardingStatus; onReset: () => void }) {
  const status = data.status
  const done = status === 'completed'
  const failed = status === 'failed'
  const reported = data.steps
  const fraction = progressFraction(data.status, data.steps)

  return (
    <div className="flex flex-col items-center gap-6 text-center">
      <div className="relative grid place-items-center pt-2">
        {done && <span className="ob-ring absolute size-56 rounded-full border border-flat-primary" aria-hidden />}
        <GemMark fill={done ? 1 : Math.max(fraction, 0.04)} className="w-44" />
      </div>
      <div className="space-y-2" role="status" aria-live="polite">
        <h2 className="text-2xl font-semibold tracking-tight text-flat-foreground">
          {done ? 'Your workspace is ready' : failed ? "Setup didn't finish" : 'Building your workspace'}
        </h2>
        <p className="mx-auto max-w-md text-sm text-flat-muted-fg">
          {done
            ? 'Everything is in place. Taking you there…'
            : failed
              ? 'Nothing from this attempt is kept.'
              : status === 'awaiting_approval'
                ? "One step needs an operator's approval. This page continues by itself."
                : 'This takes a minute or two. You can leave this page; it keeps going.'}
        </p>
      </div>
      {failed ? (
        <div className="w-full max-w-md space-y-3 rounded-md border border-flat-danger/40 bg-flat-danger/5 p-4 text-left">
          {data.error && <p className="text-sm text-flat-danger">{data.error}</p>}
          <Button size="sm" onClick={onReset}>Back to review</Button>
        </div>
      ) : (
        <ul className="w-full max-w-md space-y-2 rounded-md border border-flat-border bg-flat-surface p-4 text-left">
          {STEP_KEYS.map((key) => {
            const s = reported.find((x) => x.step === key)?.status
            return (
              <li key={key} className="flex items-center gap-3 text-sm">
                <span className="grid size-5 shrink-0 place-items-center">
                  {s === 'done' || done ? <CheckCircle2 className="size-5 text-flat-success" aria-hidden /> : s === 'running' ? <Loader2 className="size-4 animate-spin text-flat-primary" aria-hidden /> : <Circle className="size-4 text-flat-border-strong" aria-hidden />}
                </span>
                <span className={cn(s || done ? 'text-flat-foreground' : 'text-flat-muted-fg')}>{STEP_LABEL[key]}</span>
              </li>
            )
          })}
        </ul>
      )}
    </div>
  )
}
