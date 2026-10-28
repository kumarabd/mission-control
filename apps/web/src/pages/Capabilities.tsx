import { Link } from 'react-router-dom'
import { ArrowRight } from 'lucide-react'
import { InfoLayout } from '../features/landing/InfoLayout'

type Status = 'now' | 'dev' | 'next'

type Capability = {
  title: string
  where: string
  status: Status
  note: string
}

const CAPABILITIES: Capability[] = [
  {
    title: 'Assistants and conversation',
    where: 'Web · iPhone / iPad',
    status: 'now',
    note: 'Create named companions with their own instructions. Talk, return to a conversation and build on shared context.',
  },
  {
    title: 'Personal trackers and follow-through',
    where: 'iPhone / iPad',
    status: 'now',
    note: 'Goals, steps, routines and reminders. Web parity for the tailored tracker renderer is not implied.',
  },
  {
    title: 'Memory inspection',
    where: 'Web · native availability varies',
    status: 'now',
    note: 'Browse the World lens and supporting references where recorded. About you is coming soon; Reflections is not currently shown.',
  },
  {
    title: 'Delegated work',
    where: 'Depends on connected tools',
    status: 'now',
    note: 'Delegate research and drafting, review results and respond when a task needs your input. Completion, failure and cancellation are distinct states.',
  },
  {
    title: 'Connections and model choice',
    where: 'Setup and settings',
    status: 'now',
    note: 'Choose supported accounts and tools. Start with platform models or configure a supported provider or endpoint with your credentials. Some web settings lag the native controls.',
  },
  {
    title: 'Multiple companions',
    where: 'Web · native',
    status: 'now',
    note: 'Named companions with separate instructions and memory banks inside one account workspace. Independent environments per companion are next.',
  },
  {
    title: 'Proactive help and reminders',
    where: 'Native · rollout varies',
    status: 'dev',
    note: 'Scheduled and proactive experiences have their own availability. The examples on the landing page do not imply every kind of notification is live.',
  },
  {
    title: 'Customer-managed keys, own storage, more devices',
    where: 'Future direction',
    status: 'next',
    note: 'Customer-managed encryption keys, data-lifecycle controls and access from more devices. No release dates are promised.',
  },
]

const STATUS_LABEL: Record<Status, string> = {
  now: 'Available now',
  dev: 'In development',
  next: 'Next',
}

const STATUS_CLASS: Record<Status, string> = {
  now: 'lp-status-now',
  dev: 'lp-status-dev',
  next: 'lp-status-next',
}

export default function Capabilities() {
  return (
    <InfoLayout
      title="What’s available"
      description="What’s available in Mission Control by client and rollout: assistants, personal trackers, memory, delegated work, model choice, multiple companions and next directions."
    >
      <header className="lp-info-head">
        <h1>What’s available, and where.</h1>
        <p>A factual matrix. Availability varies by client and rollout; a code path is not proof that every account can use a feature.</p>
      </header>

      <div className="lp-status-legend" aria-label="Status labels used on this page">
        <span className="lp-status lp-status-now">Available now</span>
        <span className="lp-status lp-status-dev">In development</span>
        <span className="lp-status lp-status-next">Next</span>
      </div>

      <div className="lp-info-cap-table">
        {CAPABILITIES.map((capability) => (
          <div className="lp-info-cap-row" data-info-row key={capability.title}>
            <div>
              <h3>{capability.title}</h3>
              <p>{capability.note}</p>
            </div>
            <span className="lp-info-cap-where">{capability.where}</span>
            <span className={`lp-status lp-info-cap-status ${STATUS_CLASS[capability.status]}`}>
              {STATUS_LABEL[capability.status]}
            </span>
          </div>
        ))}
      </div>

      <section className="lp-info-section" data-info-reveal>
        <h2>What’s next</h2>
        <p>
          Independent environments per companion, customer-managed encryption keys, clearer data-lifecycle controls
          and access from more devices. These are directions, not current features. Goal trackers and multiple
          companion identities are already available on the clients named above.
        </p>
      </section>

      <div className="lp-info-links">
        <Link to="/privacy">How your data works <ArrowRight size={16} aria-hidden="true" /></Link>
        <Link to="/docs">Documentation <ArrowRight size={16} aria-hidden="true" /></Link>
      </div>
    </InfoLayout>
  )
}
