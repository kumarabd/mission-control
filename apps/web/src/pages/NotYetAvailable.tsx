import PageHeader from '../components/ui/PageHeader'
import type { ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { Gauge, Hash, Wrench } from 'lucide-react'

const FEATURES: Record<string, { icon: ReactNode; title: string; body: string }> = {
  budget: {
    icon: <Gauge className="size-5" />,
    title: 'Usage',
    body: 'What your assistant used and what it cost, with limits you set and a heads-up before anything overruns.',
  },
  channels: {
    icon: <Hash className="size-5" />,
    title: 'Channels',
    body: 'Reach the same assistant from Discord and other places, and see that each one is connected.',
  },
  tools: {
    icon: <Wrench className="size-5" />,
    title: 'Rules',
    body: 'Decide what your assistant may do on its own and what it must ask you about first, including requests waiting on you.',
  },
}

export default function NotYetAvailable({ feature }: { feature: keyof typeof FEATURES }) {
  const f = FEATURES[feature]
  return (
    <div>
      <PageHeader title={f.title} />
      <div className="grid justify-items-center gap-3 rounded-2xl border border-flat-border bg-flat-surface px-6 py-16 text-center">
        <span className="grid size-11 place-items-center rounded-full bg-flat-tint text-flat-primary">{f.icon}</span>
        <p className="text-lg font-medium text-flat-foreground">Coming soon</p>
        <p className="max-w-md text-base text-flat-muted-fg">{f.body}</p>
        <Link
          to="/home"
          className="mt-2 inline-flex h-9 items-center rounded-full border border-flat-border px-4 text-sm font-medium text-flat-foreground no-underline transition-colors hover:border-flat-primary hover:no-underline"
        >
          Back to Today
        </Link>
      </div>
    </div>
  )
}
