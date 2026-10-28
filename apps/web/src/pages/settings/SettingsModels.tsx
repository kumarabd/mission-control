import { useAuth } from '@clerk/clerk-react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { CheckCircle2, ChevronLeft, Loader2, XCircle } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { Badge, Button, Card, EmptyState, Field, Input, Select, Switch, toast } from '../../components/ui'
import Screen from '../../components/mission/Screen'
import { getLLM, getLLMUpdateStatus, updateLLM, type LLMTier } from '../../lib/onboarding'

const TIERS = [
  ['fast', 'Fast', 'Quick, cheap calls — routing and short replies.'],
  ['medium', 'Medium', 'The everyday workhorse. Memory retain/reflect also uses this one.'],
  ['expert', 'Expert', 'Hard reasoning and long, multi-step work.'],
] as const
type TierName = (typeof TIERS)[number][0]
type Form = { enabled: boolean; hasKey: boolean; provider: LLMTier['provider']; model: string; baseURL: string; apiKey: string }

export default function SettingsModels() {
  const { getToken } = useAuth()
  const client = useQueryClient()
  const current = useQuery({ queryKey: ['llm'], queryFn: () => getLLM(() => getToken()) })
  const [edits, setEdits] = useState<Record<TierName, Form> | null>(null)
  const [started, setStarted] = useState(false)

  const loaded = useMemo(() => current.data && (Object.fromEntries(TIERS.map(([name]) => {
    const t = current.data[name]
    return [name, { enabled: !!t?.model, hasKey: !!t?.hasKey, provider: t?.provider ?? 'openai', model: t?.model ?? '', baseURL: t?.baseURL ?? '', apiKey: '' }]
  })) as Record<TierName, Form>), [current.data])
  const form = edits ?? loaded ?? null

  // The change is a helm upgrade (~a minute) — poll its workflow until it settles.
  const status = useQuery({
    queryKey: ['llm-update'], queryFn: () => getLLMUpdateStatus(() => getToken()), enabled: started,
    refetchInterval: (q) => (q.state.data?.status === 'completed' || q.state.data?.status === 'failed' ? false : 3000),
  })
  const state = status.data?.status
  const settled = state === 'completed' || state === 'failed'
  const applying = started && !settled
  useEffect(() => {
    if (!settled) return
    void client.invalidateQueries({ queryKey: ['llm'] })
    if (state === 'completed') toast.success('Model settings applied')
  }, [settled, state, client])

  const save = useMutation({
    mutationFn: () => updateLLM(() => getToken(), Object.fromEntries(TIERS.filter(([n]) => form![n].enabled).map(([n]) => {
      const t = form![n]
      return [n, { provider: t.provider, model: t.model.trim(), baseURL: t.baseURL.trim(), apiKey: t.apiKey.trim() }]
    }))),
    onSuccess: () => {
      // Keys are now stored server-side: clear what was typed and show "saved".
      setEdits((f) => f && (Object.fromEntries(TIERS.map(([n]) => [n, { ...f[n], apiKey: '', hasKey: f[n].enabled }])) as Record<TierName, Form>))
      client.removeQueries({ queryKey: ['llm-update'] })
      setStarted(true)
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Could not save'),
  })

  const back = (
    <Link
      to="/settings"
      className="inline-flex items-center gap-1 text-flat-muted-fg hover:text-flat-foreground"
    >
      <ChevronLeft className="size-3.5" aria-hidden />
      Settings
    </Link>
  )

  if (current.isError) {
    return (
      <Screen eyebrow={back} title="Models">
        <EmptyState
          title="Couldn't load model settings"
          body={String(current.error)}
          action={{ label: 'Try again', onClick: () => void current.refetch() }}
        />
      </Screen>
    )
  }
  if (!form) {
    return (
      <Screen eyebrow={back} title="Models">
        <Loader2 className="size-4 animate-spin text-flat-muted-fg" aria-label="Loading" />
      </Screen>
    )
  }

  const set = (n: TierName, patch: Partial<Form>) => setEdits({ ...form, [n]: { ...form[n], ...patch } })
  const on = TIERS.filter(([n]) => form[n].enabled)
  const complete = on.length > 0 && on.every(([n]) => { const t = form[n]; return t.model.trim() && t.baseURL.trim() && (t.hasKey || t.apiKey.trim()) })
  const busy = applying || save.isPending

  return (
    <Screen
      eyebrow={back}
      title="Models"
      description="The LLM behind each tier. Saving redeploys your workspace’s services, which takes about a minute. Leave an API key blank to keep the saved one."
    >
    <form className="space-y-4" onSubmit={(e) => { e.preventDefault(); if (complete && !busy) save.mutate() }}>
      <Card padding="md">
        <div className="space-y-4">
          {TIERS.map(([name, label, description]) => {
            const t = form[name]
            return (
              <div key={name} className="rounded-sm border border-flat-border p-4">
                <div className="flex items-center justify-between gap-3">
                  <div>
                    <p className="text-sm font-medium text-flat-foreground">{label}</p>
                    <p className="text-xs text-flat-muted-fg">{description}</p>
                  </div>
                  <Switch checked={t.enabled} disabled={busy} onCheckedChange={(enabled) => set(name, { enabled })} />
                </div>
                {t.enabled && (
                  <div className="mt-4 grid gap-4 sm:grid-cols-2">
                    <Field label="Provider">
                      <Select value={t.provider} disabled={busy} onChange={(e) => set(name, { provider: e.target.value as LLMTier['provider'] })}
                        options={[{ value: 'openai', label: 'OpenAI-compatible' }, { value: 'anthropic', label: 'Anthropic' }]} />
                    </Field>
                    <Field label="Model" required><Input value={t.model} disabled={busy} onChange={(e) => set(name, { model: e.target.value })} /></Field>
                    <Field label="Base URL" required><Input value={t.baseURL} disabled={busy} onChange={(e) => set(name, { baseURL: e.target.value })} placeholder="https://api.example.com/v1" /></Field>
                    <Field label="API key" required={!t.hasKey} hint={t.hasKey ? 'A key is saved — leave blank to keep it.' : undefined}>
                      <Input type="password" autoComplete="new-password" value={t.apiKey} disabled={busy} onChange={(e) => set(name, { apiKey: e.target.value })} />
                    </Field>
                  </div>
                )}
              </div>
            )
          })}
          {on.length === 0 && <p className="text-sm text-flat-danger">Enable at least one tier.</p>}
        </div>
      </Card>
      <div className="flex items-center gap-3">
        <Button type="submit" disabled={!complete || busy} loading={busy}>{applying ? 'Applying…' : 'Save changes'}</Button>
        {applying && <Badge tone="accent"><Loader2 className="mr-1 inline size-3 animate-spin" />Redeploying</Badge>}
        {state === 'failed' && <span className="flex items-center gap-1 text-sm text-flat-danger"><XCircle className="size-4" />{status.data?.error || 'The update failed'}</span>}
        {state === 'completed' && !applying && <span className="flex items-center gap-1 text-sm text-flat-muted-fg"><CheckCircle2 className="size-4" />Applied</span>}
      </div>
    </form>
    </Screen>
  )
}
