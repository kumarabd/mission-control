import { useEffect, useState } from 'react'
import { ProvisioningView } from './Provisioning'
import { newWizardState, STEP_KEYS, type WizardState } from './model'
import { Wizard } from './Wizard'
import type { OnboardingStatus } from '../../lib/onboarding'

/** Dev only (`/setup-preview`): the setup screens with no sign-in or cluster. `?phase=building` plays the build. */
export default function SetupPreview() {
  const phase = new URLSearchParams(window.location.search).get('phase')
  const [state, setState] = useState<WizardState>(newWizardState)
  const [tick, setTick] = useState(0)
  useEffect(() => {
    if (phase !== 'building') return
    const t = window.setInterval(() => setTick((n) => n + 1), 900)
    return () => window.clearInterval(t)
  }, [phase])
  const done = Math.min(tick, STEP_KEYS.length)
  const data: OnboardingStatus = {
    status: done >= STEP_KEYS.length ? 'completed' : 'running',
    error: '',
    steps: [
      ...STEP_KEYS.slice(0, done).map((step) => ({ step, status: 'done' as const, message: '', updated_at: '' })),
      ...(done < STEP_KEYS.length ? [{ step: STEP_KEYS[done], status: 'running' as const, message: '', updated_at: '' }] : []),
    ],
  }
  return (
    <div className="min-h-screen bg-flat-background px-5 pt-10 text-flat-foreground">
      <div className="mx-auto max-w-xl">
        {phase === 'building' ? <ProvisioningView data={data} onReset={() => undefined} /> : <Wizard state={state} setState={setState} submitting={false} onSubmit={() => undefined} />}
      </div>
    </div>
  )
}
