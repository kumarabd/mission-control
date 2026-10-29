import { useState, type ReactNode } from 'react'
import { useNavigate } from 'react-router-dom'
import { Activity as ActivityIcon, CircleHelp, CloudOff, Flag, Scale, SquarePen } from 'lucide-react'
import { EmptyState, IconButton, Segmented, Skeleton, toast } from '../components/ui'
import Screen from '../components/mission/Screen'
import InlineError from '../components/mission/InlineError'
import ListCard from '../components/mission/ListCard'
import { formatDateTime, isLifeError } from '../lib/life'
import {
  useActivities,
  useAttention,
  useCommitments,
  useCompleteCommitment,
  useDecisions,
  useIntentions,
  useResolveDecision,
  useStates,
  type Commitment,
  type Decision,
  type Intention,
} from '../lib/life/personal'
import { useChatDraft } from '../lib/chatDraft'

type Lens = 'intentions' | 'commitments' | 'decisions' | 'state' | 'activity'

const LENSES: { value: Lens; label: string }[] = [
  { value: 'intentions', label: 'Intentions' },
  { value: 'commitments', label: 'Commitments' },
  { value: 'decisions', label: 'Decisions' },
  { value: 'state', label: 'State' },
  { value: 'activity', label: 'Activity' },
]

const EMPTY: Record<Lens, { title: string; body: string }> = {
  intentions: { title: 'Nothing you’re working toward yet', body: 'Tell your assistant what you want and it will keep it here with the work that serves it.' },
  commitments: { title: 'Nothing owed right now', body: 'Obligations you mention in chat — rent, a promise, a renewal — land here with their due date.' },
  decisions: { title: 'No decisions waiting', body: 'When a choice needs you, it appears here with its options. Your assistant can propose one from what it has noticed.' },
  state: { title: 'Nothing confirmed yet', body: 'Facts you confirm — what you can currently do, what is true about your life — are kept here, separate from memory.' },
  activity: { title: 'Nothing recorded yet', body: 'Completing a task or a commitment records an activity. What happened without a plan can be recorded too.' },
}

function message(error: unknown): string {
  return error instanceof Error ? error.message : 'Something went wrong.'
}

export default function Life() {
  const [lens, setLens] = useState<Lens>('intentions')
  const navigate = useNavigate()
  const requestDraft = useChatDraft((state) => state.request)
  const attention = useAttention()
  const due = attention.data?.commitments.length ?? 0
  const open = attention.data?.decisions.length ?? 0
  const late = attention.data?.tasks.length ?? 0

  const startNew = () => {
    requestDraft('I want to ')
    navigate('/chat')
  }

  return (
    <Screen
      title="Life"
      description="What you want, what you owe, what you’re deciding, what’s true, and what happened."
      actions={
        <IconButton label="Tell your assistant" size="lg" onClick={startNew}>
          <SquarePen aria-hidden />
        </IconButton>
      }
    >
      <Segmented className="mb-5" fullWidth value={lens} onValueChange={(next) => setLens(next as Lens)} options={LENSES} />

      {(due > 0 || open > 0 || late > 0) && (
        <div className="mb-5 grid grid-cols-3 gap-2">
          <Tile label="Due" value={due} onClick={() => setLens('commitments')} />
          <Tile label="Decisions" value={open} onClick={() => setLens('decisions')} />
          <Tile label="Overdue" value={late} onClick={() => navigate('/today')} />
        </div>
      )}

      {lens === 'intentions' && <IntentionsList onNew={startNew} />}
      {lens === 'commitments' && <CommitmentsList onNew={startNew} />}
      {lens === 'decisions' && <DecisionsList />}
      {lens === 'state' && <StatesList />}
      {lens === 'activity' && <ActivitiesList />}
    </Screen>
  )
}

function Tile({ label, value, onClick }: { label: string; value: number; onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="press rounded-flat-md border border-flat-border bg-flat-card px-3 py-2 text-left hover:bg-flat-muted/60 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-flat-primary"
    >
      <span className="block text-native-title3 font-semibold text-flat-foreground">{value}</span>
      <span className="block text-native-footnote text-flat-subtle-fg">{label}</span>
    </button>
  )
}

function Row({ title, subline, right }: { title: string; subline?: string; right?: ReactNode }) {
  return (
    <div className="flex min-h-14 items-center gap-3 border-b border-flat-border px-4 py-3 last:border-b-0">
      <span className="min-w-0 flex-1">
        <span className="block text-native-callout font-medium text-flat-foreground">{title}</span>
        {subline && <span className="mt-0.5 block text-native-footnote text-flat-subtle-fg">{subline}</span>}
      </span>
      {right}
    </div>
  )
}

function SmallButton({ children, onClick, disabled }: { children: ReactNode; onClick: () => void; disabled?: boolean }) {
  return (
    <button
      type="button"
      disabled={disabled}
      onClick={onClick}
      className="press shrink-0 rounded-full border border-flat-border px-3 py-1 text-native-footnote font-medium text-flat-foreground transition-colors hover:bg-flat-muted/60 disabled:opacity-50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-flat-primary"
    >
      {children}
    </button>
  )
}

function Lists({
  pending,
  error,
  empty,
  children,
}: {
  pending: boolean
  error: unknown
  empty: boolean
  children: ReactNode
}) {
  if (pending) return <ListSkeleton />
  if (isLifeError(error) && error.kind === 'not_provisioned') {
    return <EmptyState icon={<CloudOff />} title="Life needs your workspace" body="It isn’t reachable right now." />
  }
  if (error) {
    return <InlineError title="Couldn’t load this" description={message(error)} onRetry={() => window.location.reload()} />
  }
  if (empty) return null
  return <ListCard>{children}</ListCard>
}

function ListSkeleton() {
  return (
    <div className="flex flex-col gap-2">
      <Skeleton className="h-14 rounded-flat-md" />
      <Skeleton className="h-14 rounded-flat-md" />
      <Skeleton className="h-14 rounded-flat-md" />
    </div>
  )
}

function IntentionsList({ onNew }: { onNew: () => void }) {
  const intentions = useIntentions()
  const items = intentions.data?.items ?? []
  if (!intentions.isPending && !intentions.error && items.length === 0) {
    return <EmptyState icon={<Flag />} title={EMPTY.intentions.title} body={EMPTY.intentions.body} action={{ label: 'Tell your assistant', onClick: onNew }} />
  }
  return (
    <Lists pending={intentions.isPending} error={intentions.error} empty={false}>
      {items.map((it) => <IntentionRow key={it.id} intention={it} />)}
    </Lists>
  )
}

function IntentionRow({ intention }: { intention: Intention }) {
  const parts = [intention.kind, intention.ends_on ? `by ${intention.ends_on}` : '', progressLabel(intention)]
  return <Row title={intention.title} subline={parts.filter(Boolean).join(' · ')} />
}

function progressLabel(intention: Intention): string {
  const { done, total } = intention.progress
  return total > 0 ? `${done} of ${total} tasks done` : ''
}

function CommitmentsList({ onNew }: { onNew: () => void }) {
  const commitments = useCommitments()
  const complete = useCompleteCommitment()
  const items = commitments.data?.items ?? []
  if (!commitments.isPending && !commitments.error && items.length === 0) {
    return <EmptyState icon={<Scale />} title={EMPTY.commitments.title} body={EMPTY.commitments.body} action={{ label: 'Tell your assistant', onClick: onNew }} />
  }
  return (
    <Lists pending={commitments.isPending} error={commitments.error} empty={false}>
      {items.map((c) => (
        <CommitmentRow
          key={c.id}
          commitment={c}
          pending={complete.isPending}
          onComplete={() =>
            complete.mutate({ commitment: c }, {
              onSuccess: () => toast.success('Marked met.'),
              onError: (e) => toast.error(message(e)),
            })
          }
        />
      ))}
    </Lists>
  )
}

function CommitmentRow({ commitment, onComplete, pending }: { commitment: Commitment; onComplete: () => void; pending: boolean }) {
  const due = commitment.due_at ? formatDateTime(commitment.due_at) : commitment.due_on ?? ''
  const parts = [due && `Due ${due}`, commitment.counterparty && `to ${commitment.counterparty}`]
  return (
    <Row
      title={commitment.title}
      subline={parts.filter(Boolean).join(' · ')}
      right={commitment.status === 'open' ? <SmallButton disabled={pending} onClick={onComplete}>Mark met</SmallButton> : undefined}
    />
  )
}

function DecisionsList() {
  const decisions = useDecisions()
  const resolve = useResolveDecision()
  const items = decisions.data?.items ?? []
  if (!decisions.isPending && !decisions.error && items.length === 0) {
    return <EmptyState icon={<CircleHelp />} title={EMPTY.decisions.title} body={EMPTY.decisions.body} />
  }
  return (
    <Lists pending={decisions.isPending} error={decisions.error} empty={false}>
      {items.map((d) => (
        <DecisionRow
          key={d.id}
          decision={d}
          pending={resolve.isPending}
          onChoose={(option) =>
            resolve.mutate({ decision: d, option }, {
              onSuccess: () => toast.success('Decision recorded.'),
              onError: (e) => toast.error(message(e)),
            })
          }
        />
      ))}
    </Lists>
  )
}

function DecisionRow({ decision, onChoose, pending }: { decision: Decision; onChoose: (option: string) => void; pending: boolean }) {
  const suggested = decision.kind === 'change'
  return (
    <div className="border-b border-flat-border px-4 py-3 last:border-b-0">
      <div className="text-native-callout font-medium text-flat-foreground">{decision.question}</div>
      <div className="mt-0.5 text-native-footnote text-flat-subtle-fg">
        {suggested ? 'Suggested by your assistant · accepting applies the change' : 'Waiting on you'}
      </div>
      <div className="mt-2 flex flex-wrap gap-2">
        {decision.options.map((option) => (
          <SmallButton key={option.id} disabled={pending} onClick={() => onChoose(option.id)}>
            {option.label}
          </SmallButton>
        ))}
      </div>
    </div>
  )
}

function StatesList() {
  const states = useStates()
  const items = states.data?.items ?? []
  if (!states.isPending && !states.error && items.length === 0) {
    return <EmptyState icon={<Scale />} title={EMPTY.state.title} body={EMPTY.state.body} />
  }
  return (
    <Lists pending={states.isPending} error={states.error} empty={false}>
      {items.map((s) => (
        <Row key={s.id} title={`${s.topic} · ${s.predicate}`} subline={displayValue(s.value)} />
      ))}
    </Lists>
  )
}

function displayValue(value: unknown): string {
  if (value == null) return ''
  if (typeof value === 'string') return value
  return JSON.stringify(value)
}

function ActivitiesList() {
  const activities = useActivities()
  const items = activities.data?.items ?? []
  if (!activities.isPending && !activities.error && items.length === 0) {
    return <EmptyState icon={<ActivityIcon />} title={EMPTY.activity.title} body={EMPTY.activity.body} />
  }
  return (
    <Lists pending={activities.isPending} error={activities.error} empty={false}>
      {items.map((a) => (
        <Row key={a.id} title={a.text} subline={`${formatDateTime(a.occurred_at)} · ${a.actor}`} />
      ))}
    </Lists>
  )
}
