import { Check, ChevronLeft, ChevronRight, Eye, EyeOff, KeyRound, Lock, LockOpen, RefreshCw, Search, ShieldCheck, Sparkles } from 'lucide-react'
import { useEffect, useState } from 'react'
import { Button, Field, Input, Segmented, Switch } from '../../components/ui'
import { cn } from '../../lib/cn'
import {
  canContinue,
  canSubmit,
  newSecrets,
  SECRET_LABEL,
  SECRET_NAMES,
  STEP_TITLE,
  STEPS,
  TIER_INFO,
  TIER_NAMES,
  type SecretName,
  type StepId,
  type TierDraft,
  type TierName,
  type WizardState,
} from './model'
import { GemMark } from './GemMark'
import './onboarding.css'

type Props = {
  state: WizardState
  setState: (update: (s: WizardState) => WizardState) => void
  submitting: boolean
  onSubmit: () => void
}

/** The setup, one decision at a time: Intelligence, Security, Memory, then a review. Nothing is sent until the review. */
export function Wizard({ state, setState, submitting, onSubmit }: Props) {
  const [started, setStarted] = useState(false)
  const [index, setIndex] = useState(0)
  const [forward, setForward] = useState(true)
  const step = STEPS[index]

  const go = (to: number) => {
    setForward(to > index)
    setIndex(to)
  }

  if (!started) return <Welcome onStart={() => setStarted(true)} />

  return (
    <div className="space-y-6">
      <Stepper index={index} onJump={go} />
      <div key={step} className={forward ? 'ob-in-fwd' : 'ob-in-back'}>
        {step === 'intelligence' && <IntelligenceStep state={state} setState={setState} />}
        {step === 'security' && <SecurityStep state={state} setState={setState} />}
        {step === 'memory' && <MemoryStep state={state} setState={setState} />}
        {step === 'review' && <ReviewStep state={state} onEdit={(s) => go(STEPS.indexOf(s))} />}
      </div>
      <div className="flex items-center gap-3">
        <Button variant="secondary" size="lg" onClick={() => (index === 0 ? setStarted(false) : go(index - 1))} aria-label="Back" iconLeft={<ChevronLeft className="size-4" />}>
          Back
        </Button>
        {step === 'review' ? (
          <Button variant="primary" size="lg" fullWidth loading={submitting} disabled={!canSubmit(state) || submitting} onClick={onSubmit}>
            Create my workspace
          </Button>
        ) : (
          <Button variant="primary" size="lg" fullWidth disabled={!canContinue(state, step)} onClick={() => go(index + 1)} iconRight={<ChevronRight className="size-4" />}>
            Continue
          </Button>
        )}
      </div>
    </div>
  )
}

function Welcome({ onStart }: { onStart: () => void }) {
  const points = [
    { icon: ShieldCheck, title: 'Private by design', body: 'Your workspace is yours alone, with its own database.' },
    { icon: Sparkles, title: 'Set up once', body: 'A few choices now, and we do the rest.' },
    { icon: RefreshCw, title: 'About a minute', body: "We build it while you watch, then you're in." },
  ]
  return (
    <div className="flex flex-col items-center gap-8 pt-4 text-center">
      <GemMark className="ob-float w-44" fill={1} trace />
      <div className="space-y-2">
        <h2 className="text-2xl font-semibold tracking-tight text-flat-foreground">Let&rsquo;s build your private workspace</h2>
        <p className="mx-auto max-w-md text-sm text-flat-muted-fg">Your own memory, tools and AI models, in a space only you can open.</p>
      </div>
      <ul className="w-full max-w-md space-y-3 text-left">
        {points.map(({ icon: Icon, title, body }, i) => (
          <li key={title} className="ob-rise flex items-center gap-4" style={{ ['--i' as string]: i + 3 }}>
            <Icon className="size-6 shrink-0 text-flat-primary" aria-hidden />
            <div>
              <p className="text-sm font-medium text-flat-foreground">{title}</p>
              <p className="text-xs text-flat-muted-fg">{body}</p>
            </div>
          </li>
        ))}
      </ul>
      <Button variant="primary" size="lg" fullWidth className="max-w-md" onClick={onStart} iconRight={<ChevronRight className="size-4" />}>
        Get started
      </Button>
    </div>
  )
}

function Stepper({ index, onJump }: { index: number; onJump: (i: number) => void }) {
  return (
    <nav aria-label="Setup progress" className="space-y-3">
      <ol className="flex gap-1.5">
        {STEPS.map((s, i) => (
          <li key={s} className="flex-1">
            <button
              type="button"
              disabled={i > index}
              onClick={() => onJump(i)}
              aria-label={STEP_TITLE[s]}
              aria-current={i === index ? 'step' : undefined}
              className="ob-pip block h-6 w-full disabled:cursor-default"
            >
              <span className="relative block h-1.5 w-full overflow-hidden rounded-full bg-flat-muted">
                <i className="absolute inset-0 rounded-full bg-flat-primary" style={{ transform: `scaleX(${i <= index ? 1 : 0})` }} />
              </span>
            </button>
          </li>
        ))}
      </ol>
      <div className="flex items-center justify-between text-sm">
        <span className="font-medium text-flat-foreground">{STEP_TITLE[STEPS[index]]}</span>
        <span className="tabular-nums text-flat-muted-fg">
          {index + 1} of {STEPS.length}
        </span>
      </div>
    </nav>
  )
}

function StepHeading({ title, body }: { title: string; body: string }) {
  return (
    <div className="mb-5 space-y-1.5">
      <h2 className="text-2xl font-semibold tracking-tight text-flat-foreground">{title}</h2>
      <p className="text-sm text-flat-muted-fg">{body}</p>
    </div>
  )
}

function Choice({ icon: Icon, title, body, badge, selected, onClick }: { icon: typeof Sparkles; title: string; body: string; badge?: string; selected: boolean; onClick: () => void }) {
  return (
    <button
      type="button"
      role="radio"
      aria-checked={selected}
      onClick={onClick}
      className={cn(
        'ob-choice flex w-full items-start gap-4 rounded-md border bg-flat-surface p-4 text-left',
        selected ? 'border-flat-primary shadow-[0_8px_24px_-12px_var(--color-flat-primary)]' : 'border-flat-border hover:border-flat-border-strong',
      )}
    >
      <Icon className={cn('mt-0.5 size-6 shrink-0', selected ? 'text-flat-primary' : 'text-flat-muted-fg')} aria-hidden />
      <span className="flex-1 space-y-1">
        <span className="flex items-center gap-2 text-sm font-medium text-flat-foreground">
          {title}
          {badge && <span className="rounded-full bg-flat-tint px-2 py-0.5 text-2xs font-semibold uppercase tracking-wide text-flat-primary">{badge}</span>}
        </span>
        <span className="block text-sm text-flat-muted-fg">{body}</span>
      </span>
      <span className={cn('mt-0.5 grid size-5 shrink-0 place-items-center rounded-full border', selected ? 'border-flat-primary bg-flat-primary text-flat-on-primary' : 'border-flat-border-strong')}>
        {selected && <Check className="size-3.5" aria-hidden />}
      </span>
    </button>
  )
}

type StepProps = { state: WizardState; setState: Props['setState'] }

function IntelligenceStep({ state, setState }: StepProps) {
  const updateTier = (name: TierName, patch: Partial<TierDraft>) =>
    setState((s) => ({ ...s, tiers: { ...s.tiers, [name]: { ...s.tiers[name], ...patch } } }))
  return (
    <div>
      <StepHeading title="Intelligence" body="Choose the models that power your workspace's assistant features." />
      <div role="radiogroup" aria-label="Models" className="space-y-3">
        <Choice icon={Sparkles} title="Our models" body="Works out of the box. Nothing to set up." badge="Recommended" selected={state.intelligence === 'platform'} onClick={() => setState((s) => ({ ...s, intelligence: 'platform' }))} />
        <Choice icon={KeyRound} title="Bring my own" body="Use your own provider and API key." selected={state.intelligence === 'own'} onClick={() => setState((s) => ({ ...s, intelligence: 'own' }))} />
      </div>
      {state.intelligence === 'own' && (
        <div className="ob-rise mt-4 space-y-3">
          {TIER_NAMES.map((name) => {
            const t = state.tiers[name]
            const baseURLRequired = t.provider !== 'anthropic'
            return (
              <div key={name} className="rounded-md border border-flat-border bg-flat-surface p-4">
                <div className="flex items-center justify-between gap-3">
                  <div>
                    <p className="text-sm font-medium text-flat-foreground">{TIER_INFO[name].label}</p>
                    <p className="text-xs text-flat-muted-fg">{TIER_INFO[name].description}</p>
                  </div>
                  {name === 'medium' ? <span className="text-xs font-semibold text-flat-primary">Required</span> : <Switch checked={t.enabled} onCheckedChange={(enabled) => updateTier(name, { enabled })} />}
                </div>
                {t.enabled && (
                  <div className="ob-rise mt-4 grid gap-4 sm:grid-cols-2">
                    <Field label="Provider" className="sm:col-span-2">
                      <Segmented
                        value={t.provider}
                        onValueChange={(provider) => updateTier(name, { provider })}
                        options={[{ value: 'openai', label: 'OpenAI-compatible' }, { value: 'anthropic', label: 'Anthropic' }]}
                      />
                    </Field>
                    <Field label="Model" required>
                      <Input value={t.model} onChange={(e) => updateTier(name, { model: e.target.value })} placeholder={t.provider === 'anthropic' ? 'claude-sonnet-5-5' : 'gpt-4o-mini'} />
                    </Field>
                    <Field label="Base URL" required={baseURLRequired} hint={!baseURLRequired ? 'Optional for Anthropic.' : undefined}>
                      <Input value={t.baseURL} onChange={(e) => updateTier(name, { baseURL: e.target.value })} placeholder="https://api.example.com/v1" />
                    </Field>
                    <Field label="API key" required className="sm:col-span-2">
                      <SecretInput value={t.apiKey} onChange={(apiKey) => updateTier(name, { apiKey })} />
                    </Field>
                  </div>
                )}
              </div>
            )
          })}
        </div>
      )}
    </div>
  )
}

function SecretInput({ value, onChange, label }: { value: string; onChange: (v: string) => void; label?: string }) {
  const [visible, setVisible] = useState(false)
  return (
    <div className="flex gap-2">
      <Input type={visible ? 'text' : 'password'} value={value} onChange={(e) => onChange(e.target.value)} spellCheck={false} autoComplete="new-password" className="font-mono" aria-label={label} />
      <Button type="button" variant="ghost" aria-label={visible ? 'Hide value' : 'Show value'} onClick={() => setVisible((v) => !v)}>
        {visible ? <EyeOff className="size-4" /> : <Eye className="size-4" />}
      </Button>
    </div>
  )
}

function SecurityStep({ state, setState }: StepProps) {
  const [sealed, setSealed] = useState(false)
  const [custom, setCustom] = useState(false)
  const [spins, setSpins] = useState(0)
  useEffect(() => {
    const t = window.setTimeout(() => setSealed(true), 450)
    return () => window.clearTimeout(t)
  }, [])
  return (
    <div>
      <StepHeading title="Security" body="Your workspace is locked with its own keys. We made them for you, they are used once to set it up, and you never have to remember them." />
      <div className="rounded-md border border-flat-border bg-flat-surface p-4">
        <div className="flex items-center gap-3">
          {sealed ? <Lock className="size-6 text-flat-primary" aria-hidden /> : <LockOpen className="size-6 text-flat-primary" aria-hidden />}
          <div>
            <p className="text-sm font-medium text-flat-foreground">{sealed ? 'Keys generated' : 'Generating keys…'}</p>
            <p className="text-xs text-flat-muted-fg">Random, made in your browser.</p>
          </div>
        </div>
        <ul className="mt-4 space-y-2">
          {SECRET_NAMES.map((n, i) => (
            <li key={n} className="flex items-center gap-3 text-sm">
              <span className="flex-1 text-flat-foreground">{SECRET_LABEL[n]}</span>
              <span className="font-mono tracking-widest text-flat-muted-fg">{sealed ? '••••••••' : ''}</span>
              <span className={cn('grid size-5 place-items-center rounded-full bg-flat-success text-white', sealed ? 'ob-pop' : 'opacity-0')} style={{ ['--i' as string]: i }}>
                <Check className="size-3.5" aria-hidden />
              </span>
            </li>
          ))}
        </ul>
        <Button
          type="button"
          variant="ghost"
          size="sm"
          className="mt-3"
          onClick={() => {
            setState((s) => ({ ...s, secrets: newSecrets() }))
            setSpins((n) => n + 1)
          }}
          iconLeft={<RefreshCw className="ob-spin-once size-4" style={{ transform: `rotate(${spins * 360}deg)` }} />}
        >
          Generate new keys
        </Button>
      </div>
      <button type="button" className="mt-3 flex h-10 w-full items-center justify-between text-sm font-medium text-flat-muted-fg" aria-expanded={custom} onClick={() => setCustom((v) => !v)}>
        Set them myself
        <ChevronRight className={cn('size-4 transition-transform', custom && 'rotate-90')} aria-hidden />
      </button>
      {custom && (
        <div className="ob-rise grid gap-4 sm:grid-cols-2">
          {SECRET_NAMES.map((n: SecretName) => (
            <Field key={n} label={SECRET_LABEL[n]}>
              <SecretInput value={state.secrets[n]} onChange={(v) => setState((s) => ({ ...s, secrets: { ...s.secrets, [n]: v } }))} label={SECRET_LABEL[n]} />
            </Field>
          ))}
        </div>
      )}
    </div>
  )
}

function MemoryStep({ state, setState }: StepProps) {
  return (
    <div>
      <StepHeading title="Memory" body="Your workspace can search what it remembers. That needs an embedding model." />
      <div role="radiogroup" aria-label="Embedding model" className="space-y-3">
        <Choice icon={Search} title="Our embedding model" body="Shared and ready. No setup." badge="Recommended" selected={state.usePlatformEmbedding} onClick={() => setState((s) => ({ ...s, usePlatformEmbedding: true }))} />
        <Choice icon={KeyRound} title="My own endpoint" body="Use a different embedding provider." selected={!state.usePlatformEmbedding} onClick={() => setState((s) => ({ ...s, usePlatformEmbedding: false }))} />
      </div>
      {!state.usePlatformEmbedding && (
        <div className="ob-rise mt-4">
          <Field label="Embedding API key" required>
            <SecretInput value={state.embeddingKey} onChange={(embeddingKey) => setState((s) => ({ ...s, embeddingKey }))} />
          </Field>
        </div>
      )}
    </div>
  )
}

function ReviewStep({ state, onEdit }: { state: WizardState; onEdit: (s: StepId) => void }) {
  const own = TIER_NAMES.filter((n) => state.tiers[n].enabled).length
  const rows: { step: StepId; icon: typeof Sparkles; value: string }[] = [
    { step: 'intelligence', icon: Sparkles, value: state.intelligence === 'platform' ? 'Our models' : `${own} of your own model${own === 1 ? '' : 's'}` },
    { step: 'security', icon: ShieldCheck, value: 'Generated keys' },
    { step: 'memory', icon: Search, value: state.usePlatformEmbedding ? 'Our embedding model' : 'Your own endpoint' },
  ]
  return (
    <div>
      <StepHeading title="Ready to build" body="Check your choices. Select any row to change it." />
      <ul className="space-y-3">
        {rows.map(({ step, icon: Icon, value }, i) => (
          <li key={step} className="ob-rise" style={{ ['--i' as string]: i }}>
            <button type="button" onClick={() => onEdit(step)} className="ob-choice flex w-full items-center gap-4 rounded-md border border-flat-border bg-flat-surface p-4 text-left hover:border-flat-border-strong">
              <Icon className="size-5 text-flat-primary" aria-hidden />
              <span className="flex-1">
                <span className="block text-xs text-flat-muted-fg">{STEP_TITLE[step]}</span>
                <span className="block text-sm text-flat-foreground">{value}</span>
              </span>
              <ChevronRight className="size-4 text-flat-muted-fg" aria-hidden />
            </button>
          </li>
        ))}
      </ul>
      <p className="mt-4 text-xs text-flat-muted-fg">Nothing is kept if setup fails. You would simply start the review again.</p>
    </div>
  )
}
