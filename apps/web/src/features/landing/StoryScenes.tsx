import { useEffect, useRef, useState } from 'react'
import { animate } from 'animejs'
import {
  ArrowRight,
  Bell,
  BookOpen,
  Briefcase,
  CalendarDays,
  Check,
  ChevronDown,
  Cpu,
  Eye,
  Fingerprint,
  Folder,
  GraduationCap,
  LockKeyhole,
  MessageCircle,
  Mic,
  MoreHorizontal,
  Phone,
  Plus,
  Search,
  ShieldCheck,
  Sparkles,
} from 'lucide-react'

const still = () => typeof matchMedia === 'function' && matchMedia('(prefers-reduced-motion: reduce)').matches

export function CompanionMark({ small = false }: { small?: boolean }) {
  return (
    <span className={'lp-companion-mark' + (small ? ' lp-companion-mark-small' : '')} aria-hidden="true">
      <Sparkles strokeWidth={1.3} />
    </span>
  )
}

/* ------------------------------------------------------------------ */
/* 01 — Continuity                                                    */
/* ------------------------------------------------------------------ */

export function ContinuityScene() {
  return (
    <div
      className="lp-scene lp-continuity"
      role="img"
      aria-label="Illustrative example: one companion shares one memory across a phone, a laptop and a chosen check-in."
    >
      <span className="lp-thread" aria-hidden="true">
        <i className="lp-thread-line" />
        <i className="lp-thread-dot lp-thread-dot-top" />
        <i className="lp-thread-dot lp-thread-dot-bottom" />
      </span>

      <div className="lp-phone lp-continuity-card">
        <div className="lp-phone-head">
          <CompanionMark small />
          <div className="lp-phone-name">
            <strong>Mira</strong>
            <span>Everyday companion</span>
          </div>
          <MoreHorizontal size={16} className="lp-phone-more" aria-hidden="true" />
        </div>
        <div className="lp-phone-body">
          <div className="lp-bubble lp-bubble-user">I want to learn Spanish, 20 minutes on weekdays.</div>
          <div className="lp-bubble lp-bubble-mira">
            <CompanionMark small />
            <span>Let’s make it part of your week. Start with 10 minutes listening, 10 minutes vocabulary.</span>
          </div>
          <div className="lp-chip"><BookOpen size={13} aria-hidden="true" /> Remembers · weekdays</div>
        </div>
        <div className="lp-phone-voice">
          <span className="lp-voice-circle"><Mic size={16} aria-hidden="true" /></span>
          <span className="lp-voice-label">Hold to talk</span>
          <span className="lp-send-circle"><ArrowRight size={14} aria-hidden="true" /></span>
        </div>
      </div>

      <div className="lp-laptop lp-continuity-card">
        <div className="lp-laptop-bar">
          <span className="lp-laptop-dots" aria-hidden="true"><i /><i /><i /></span>
          <strong>Mission Control — Mira</strong>
          <Sparkles size={14} aria-hidden="true" />
        </div>
        <div className="lp-laptop-body">
          <div className="lp-memory-row">
            <span>Remembered</span>
            <i>Spanish · weekdays</i>
            <i>Keep it short</i>
          </div>
          <p className="lp-laptop-message">You said weekdays work best. Want a 5-minute version for busy days?</p>
          <div className="lp-source"><Phone size={12} aria-hidden="true" /> from your phone</div>
        </div>
      </div>

      <div className="lp-checkin lp-continuity-card">
        <span className="lp-checkin-icon"><Bell size={16} aria-hidden="true" /></span>
        <div className="lp-checkin-copy">
          <span>A check-in you chose</span>
          <p>Practice today? 10 minutes is enough.</p>
        </div>
        <span className="lp-checkin-time">Now</span>
      </div>

      <span className="lp-token" aria-hidden="true">
        <BookOpen size={11} aria-hidden="true" /> Spanish · weekdays
      </span>

      <p className="lp-scene-note">Illustrative example</p>
    </div>
  )
}

/* ------------------------------------------------------------------ */
/* 02 — Memory                                                        */
/* ------------------------------------------------------------------ */

function MemoryRow({ icon, title, source }: { icon: React.ReactNode; title: string; source: string }) {
  return (
    <div className="lp-memory-item" data-memory-row>
      <span className="lp-memory-icon">{icon}</span>
      <div className="lp-memory-copy">
        <strong>{title}</strong>
        <span>{source}</span>
      </div>
      <Eye size={15} className="lp-memory-action" aria-hidden="true" />
    </div>
  )
}

export function MemoryScene() {
  return (
    <div
      className="lp-scene lp-memory"
      role="img"
      aria-label="Illustrative example: an inspectable memory panel with remembered facts, their sources and a separate memory bank for Mira."
    >
      <div className="lp-memory-panel">
        <div className="lp-panel-head">
          <h3>What Mira remembers</h3>
          <span className="lp-search"><Search size={13} aria-hidden="true" /> Search memory</span>
        </div>
        <div className="lp-tabs">
          <span className="lp-pill lp-pill-on">Memory</span>
          <span className="lp-pill">Sources</span>
        </div>
        <div className="lp-memory-list">
          <MemoryRow icon={<BookOpen size={15} />} title="Learning Spanish · 20 minutes on weekdays" source="From a goal · Added 12 Sep" />
          <div className="lp-memory-item lp-memory-item-open" data-memory-row>
            <i className="lp-memory-link" aria-hidden="true" />
            <div className="lp-memory-open-top">
              <span className="lp-memory-icon"><MessageCircle size={15} /></span>
              <div className="lp-memory-copy">
                <strong>Prefers short, practical check-ins</strong>
                <span>From a conversation · 8 Sep</span>
              </div>
              <ChevronDown size={15} className="lp-memory-action" aria-hidden="true" />
            </div>
            <div className="lp-memory-detail">
              <p>“Keep it short and practical.”</p>
              <div className="lp-memory-actions">
                <span className="lp-pill lp-pill-link">View source <ArrowRight size={11} /></span>
              </div>
            </div>
          </div>
          <MemoryRow icon={<CalendarDays size={15} />} title="Book club on Thursday evenings" source="You shared this · 2 Sep" />
          <MemoryRow icon={<Bell size={15} />} title="Doesn’t want morning notifications" source="From a preference · 28 Aug" />
        </div>
        <p className="lp-panel-foot">4 memories · 2 sources</p>
      </div>

      <aside className="lp-bank">
        <Sparkles size={18} aria-hidden="true" />
        <strong>Mira</strong>
        <span>Everyday memory bank</span>
        <p><span data-memory-count="24">24</span> items · separate from other companions</p>
        <small>Select any row to see its source.</small>
      </aside>

      <p className="lp-scene-note">Illustrative example</p>
    </div>
  )
}

/* ------------------------------------------------------------------ */
/* 03 — Boundary                                                      */
/* ------------------------------------------------------------------ */

function PermissionRow({ icon, label, on }: { icon: React.ReactNode; label: string; on: boolean }) {
  return (
    <div className="lp-permission-row">
      <span className="lp-permission-label">{icon}{label}</span>
      <span className={'lp-toggle ' + (on ? 'lp-toggle-on' : 'lp-toggle-off')} aria-hidden="true">
        <i className="lp-toggle-track">
          <i className="lp-toggle-fill" />
          <i className="lp-toggle-thumb" />
        </i>
      </span>
    </div>
  )
}

export function BoundaryScene() {
  return (
    <div
      className="lp-scene lp-boundary"
      role="img"
      aria-label="Illustrative example: permission toggles, an approval request, a model choice and a visible route from the workspace to a model provider."
    >
      <div className="lp-boundary-panel">
        <div className="lp-panel-head">
          <ShieldCheck size={18} aria-hidden="true" />
          <h3>What Mira can use</h3>
        </div>
        <PermissionRow icon={<CalendarDays size={16} />} label="Calendar" on />
        <PermissionRow icon={<Folder size={16} />} label="Files" on />
        <PermissionRow icon={<MessageCircle size={16} />} label="Messages" on={false} />
        <div className="lp-model-row">
          <span className="lp-model-left">
            <Cpu size={16} aria-hidden="true" />
            <span><small>Model</small><strong>Platform model</strong></span>
          </span>
          <ChevronDown size={14} aria-hidden="true" />
        </div>
        <p className="lp-panel-note">Or connect a provider with your own credentials.</p>
      </div>

      <div className="lp-boundary-side">
        <div className="lp-approval">
          <div className="lp-approval-head"><LockKeyhole size={15} aria-hidden="true" /><span>Approval needed</span></div>
          <h3>Mira wants to send an email.</h3>
          <p>To Alex · Book club</p>
          <span className="lp-pill">1 draft · shared context</span>
          <div className="lp-approval-actions">
            <span className="lp-btn-ghost">Decline</span>
            <span className="lp-btn-solid">Approve</span>
          </div>
        </div>

        <div className="lp-route">
          <span className="lp-route-label">What leaves your space</span>
          <p>Only the context needed for this request goes to the model you chose.</p>
          <div className="lp-route-row">
            <i className="lp-route-track" aria-hidden="true" />
            <i className="lp-route-packet" aria-hidden="true" />
            <span className="lp-route-chip">Your workspace</span>
            <ArrowRight size={14} aria-hidden="true" />
            <span className="lp-route-chip">Model provider</span>
          </div>
          <small>Connected services receive their own requests.</small>
        </div>
      </div>

      <p className="lp-scene-note">Illustrative example</p>
    </div>
  )
}

/* ------------------------------------------------------------------ */
/* 04 — Companions                                                    */
/* ------------------------------------------------------------------ */

function CompanionCard({
  name,
  role,
  instruction,
  memoryCount,
  memory,
  scopes,
  icon,
  active = false,
  className = '',
}: {
  name: string
  role: string
  instruction: string
  memoryCount: number
  memory: string
  scopes: string[]
  icon: React.ReactNode
  active?: boolean
  className?: string
}) {
  return (
    <article className={'lp-companion-card ' + className + (active ? ' lp-companion-active' : '')} data-companion-card>
      <div className="lp-companion-top">
        <span className="lp-companion-avatar">{icon}</span>
        {active && <span className="lp-pill lp-pill-on">Active</span>}
      </div>
      <h3>{name}</h3>
      <span className="lp-companion-role">{role}</span>
      <p>{instruction}</p>
      <i className="lp-companion-divider" />
      <small>Memory bank</small>
      <strong className="lp-companion-memory"><span data-count={memoryCount}>{memoryCount}</span> {memory}</strong>
      <div className="lp-companion-scopes">
        {scopes.map((scope) => <span className="lp-pill" key={scope}>{scope}</span>)}
      </div>
    </article>
  )
}

export function CompanionsScene() {
  return (
    <div
      className="lp-scene lp-companions"
      role="img"
      aria-label="Illustrative example: three named companions with different instructions, scopes and separate memory banks."
    >
      <div className="lp-companion-tabs">
        <span className="lp-pill lp-pill-on">Mira</span>
        <span className="lp-pill">Atlas</span>
        <span className="lp-pill">June</span>
      </div>
      <div className="lp-companion-stage">
        <CompanionCard
          name="Atlas" role="Work companion" instruction="Direct, concise. Numbers first."
          memoryCount={2} memory="projects · 1 decision" scopes={['Web', 'Work']} icon={<Briefcase size={20} />}
          className="lp-companion-atlas"
        />
        <CompanionCard
          name="Mira" role="Everyday companion" instruction="Warm, practical, brief."
          memoryCount={24} memory="items · Spanish, book club, check-ins" scopes={['iPhone', 'iPad', 'Web']} icon={<Sparkles size={20} />}
          active className="lp-companion-mira"
        />
        <CompanionCard
          name="June" role="Learning companion" instruction="Curious, patient. Asks questions."
          memoryCount={12} memory="items · Spanish" scopes={['iPad']} icon={<GraduationCap size={20} />}
          className="lp-companion-june"
        />
      </div>
      <span className="lp-add-companion"><Plus size={14} aria-hidden="true" /> Add companion</span>
      <p className="lp-scene-note">Illustrative example</p>
    </div>
  )
}

/* ------------------------------------------------------------------ */
/* 05 — Artifact                                                      */
/* ------------------------------------------------------------------ */

function PlanItem({ label, time }: { label: string; time: string }) {
  return (
    <div className="lp-plan-item" data-plan-item>
      <span className="lp-plan-check"><Check size={11} aria-hidden="true" /></span>
      <span>{label}</span>
      <span className="lp-pill">{time}</span>
    </div>
  )
}

export function ArtifactScene() {
  return (
    <div
      className="lp-scene lp-artifact"
      role="img"
      aria-label="Illustrative example: a conversation becomes a draft day plan with review and adjust actions."
    >
      <div className="lp-chat-card">
        <p className="lp-bubble lp-bubble-user">I have a busy afternoon. Help me choose what to focus on.</p>
        <p className="lp-bubble lp-bubble-mira">Here’s a draft day plan. We can move anything that doesn’t fit.</p>
        <span className="lp-source"><Sparkles size={12} aria-hidden="true" /> From a conversation · Mira</span>
      </div>

      <div className="lp-plan-card">
        <div className="lp-plan-head">
          <h3>Today, with some breathing room</h3>
          <span className="lp-pill lp-pill-on">Draft</span>
        </div>
        <p className="lp-plan-sub">A proposed plan for you to review.</p>
        <PlanItem label="Prepare the workshop outline" time="30 min" />
        <PlanItem label="Reply to the two pending questions" time="15 min" />
        <PlanItem label="Leave a gap between commitments" time="—" />
        <div className="lp-plan-actions">
          <span className="lp-btn-solid">Review plan</span>
          <span className="lp-btn-ghost">Adjust</span>
        </div>
        <small className="lp-plan-note">Nothing is sent until you approve.</small>
      </div>

      <span className="lp-artifact-spark" aria-hidden="true">
        <Sparkles size={11} aria-hidden="true" /> Draft plan
      </span>

      <p className="lp-scene-note">Illustrative example</p>
    </div>
  )
}

/* ------------------------------------------------------------------ */
/* How — a local creation preview                                      */
/* ------------------------------------------------------------------ */

const STYLES = ['Practical & direct', 'Curious & thoughtful', 'Warm & encouraging']

export function CreationPreview() {
  const [name, setName] = useState('Mira')
  const [style, setStyle] = useState(0)
  const preview = useRef<HTMLDivElement>(null)
  const root = useRef<HTMLDivElement>(null)
  const interacted = useRef(false)

  // Until the visitor takes over, the preview demonstrates what shaping a
  // companion does: each style choice visibly changes the card.
  useEffect(() => {
    if (still() || !root.current) return
    const el = root.current
    const timers: number[] = []
    const io = new IntersectionObserver((entries) => {
      if (!entries.some((entry) => entry.isIntersecting) || interacted.current) return
      io.disconnect()
      ;[1, 2, 0].forEach((next, index) => {
        timers.push(window.setTimeout(() => {
          if (!interacted.current) setStyle(next)
        }, 1400 * (index + 1)))
      })
    }, { threshold: 0.5 })
    io.observe(el)
    return () => {
      io.disconnect()
      timers.forEach((timer) => window.clearTimeout(timer))
    }
  }, [])

  useEffect(() => {
    if (!preview.current || still()) return
    const animation = animate(preview.current, {
      scale: [0.97, 1],
      rotate: [-1.2, 0],
      duration: 520,
      ease: 'outBack',
    })
    const shine = preview.current.querySelector('.lp-preview-shine')
    const sweep = shine
      ? animate(shine, {
          translateX: ['-180%', '380%'],
          opacity: [0, 0.55, 0],
          duration: 760,
          ease: 'inOutSine',
        })
      : null
    return () => {
      animation.revert()
      sweep?.revert()
    }
  }, [name, style])

  return (
    <div className="lp-create" ref={root}>
      <div className="lp-create-controls">
        <label htmlFor="lp-companion-name">A name that feels right</label>
        <div className="lp-name-field">
          <input
            id="lp-companion-name"
            value={name}
            maxLength={32}
            onChange={(event) => {
              interacted.current = true
              setName(event.target.value)
            }}
            onFocus={() => { interacted.current = true }}
            autoComplete="off"
            spellCheck={false}
          />
          <Sparkles size={18} aria-hidden="true" />
        </div>
        <span>Make the conversation your own</span>
        <div className="lp-style-pills" role="group" aria-label="Example companion style">
          {STYLES.map((label, index) => (
            <button key={label} type="button" aria-pressed={style === index} onClick={() => {
              interacted.current = true
              setStyle(index)
            }}>
              {label}
              {style === index && <Check size={14} aria-hidden="true" />}
            </button>
          ))}
        </div>
      </div>

      <div className="lp-create-preview" ref={preview}>
        <span className="lp-preview-shine" aria-hidden="true" />
        <div className="lp-preview-top"><Fingerprint size={20} aria-hidden="true" /><span>Shaped by you</span></div>
        <CompanionMark />
        <strong>{name.trim() || 'Your companion'}</strong>
        <span>{STYLES[style]}</span>
        <p>“What would you like a hand with?”</p>
        <small><i /> A companion of your own</small>
      </div>

      <p className="lp-scene-note">A local preview. Create your account to set up the real thing.</p>
    </div>
  )
}
