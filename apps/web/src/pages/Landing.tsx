import { useEffect, useRef } from 'react'
import { Link, useLocation } from 'react-router-dom'
import { ArrowDown, ArrowRight, ArrowUpRight, Play } from 'lucide-react'
import { useExplorerAuth } from '../auth/context'
import { LandingFooter, LandingHeader } from '../features/landing/Chrome'
import { landingAction } from '../features/landing/model'
import {
  ArtifactScene,
  BoundaryScene,
  CompanionMark,
  CompanionsScene,
  ContinuityScene,
  CreationPreview,
  MemoryScene,
} from '../features/landing/StoryScenes'
import { useLandingMotion } from '../features/landing/motion'
import { usePageMeta } from '../features/landing/meta'
import '../features/landing/landing.css'

export default function Landing() {
  const auth = useExplorerAuth()
  const action = landingAction(auth)
  const root = useRef<HTMLDivElement>(null)
  const location = useLocation()
  useLandingMotion(root)

  usePageMeta(
    'Mission Control — Create your personal AI companion',
    'Create a personal AI companion for everyday life. One memory across your devices, with privacy and control at the heart.',
  )

  // Info-page navigation uses /#why, /#what and /#companions. React Router
  // changes the hash without scrolling a client-rendered page, so do it here.
  useEffect(() => {
    if (!location.hash) return
    const target = document.getElementById(location.hash.slice(1))
    if (!target) return
    const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches
    target.scrollIntoView({ behavior: reduce ? 'auto' : 'smooth', block: 'start' })
  }, [location.hash])

  return (
    <div className="lp" ref={root}>
      <div className="lp-reading-progress" aria-hidden="true" />
      <a className="lp-skip" href="#hero">Skip to content</a>

      <LandingHeader action={action} showAction={false} />

      <div className="lp-rail" aria-hidden="true">
        <span className="lp-rail-line" />
        <span className="lp-rail-fill" />
        <span className="lp-rail-pulse" />
        <span className="lp-rail-node" data-rail-node="hero" />
        <span className="lp-rail-node" data-rail-node="why" />
        <span className="lp-rail-node" data-rail-node="what" />
        <span className="lp-rail-node" data-rail-node="companions" />
        <span className="lp-rail-node" data-rail-node="how" />
        <span className="lp-rail-node" data-rail-node="closing" />
      </div>

      <main>
        <section className="lp-hero lp-section" id="hero" aria-labelledby="lp-hero-title">
          <div className="lp-hero-copy">
            <h1 id="lp-hero-title">Where your personal AI <em>comes to life.</em></h1>
            <p className="lp-hero-lede">
              Talk or type. One companion, one memory — across your devices.
            </p>
            <div className="lp-hero-action">
              <Link to={action.to} className="lp-button">
                {action.label}
                <ArrowUpRight size={17} aria-hidden="true" />
              </Link>
              {action.earlyAccess && <span>Early access · Account setup comes first</span>}
            </div>
            <a href="#what" className="lp-watch-link">
              <span><Play size={12} fill="currentColor" aria-hidden="true" /></span>
              Explore the possibilities
              <ArrowDown size={15} aria-hidden="true" />
            </a>
          </div>
          <div className="lp-hero-scene">
            <ContinuityScene />
          </div>
        </section>

        <section className="lp-section lp-why" id="why" aria-labelledby="lp-why-title">
          <span className="lp-seam" aria-hidden="true" />
          <div className="lp-section-head">
            <h2 id="lp-why-title">It should know you <em>without owning you.</em></h2>
            <p>Your memory, records and conversations live in your workspace. You choose what it sees and how it’s powered.</p>
          </div>
          <div className="lp-why-grid">
            <div className="lp-why-block">
              <h3>See what it remembers.</h3>
              <div className="lp-parallax" data-parallax><MemoryScene /></div>
            </div>
            <div className="lp-why-block">
              <h3>You decide what it can reach.</h3>
              <div className="lp-parallax" data-parallax><BoundaryScene /></div>
            </div>
          </div>
          <Link to="/privacy" className="lp-text-link">
            How your data works <ArrowRight size={17} aria-hidden="true" />
          </Link>
        </section>

        <section className="lp-section lp-what" id="what" aria-labelledby="lp-what-title">
          <span className="lp-seam" aria-hidden="true" />
          <div className="lp-section-head">
            <h2 id="lp-what-title">Help for whatever <em>comes up.</em></h2>
            <p>Plan, draft, think it through — by voice or text.</p>
          </div>
          <div className="lp-pin" data-pin>
            <div className="lp-pin-stage">
              <div className="lp-parallax" data-parallax><ArtifactScene /></div>
            </div>
          </div>
          <p className="lp-section-note">A plan, a draft, a tracker — reviewed before anything happens.</p>
        </section>

        <section className="lp-section lp-companions-section" id="companions" aria-labelledby="lp-companions-title">
          <span className="lp-seam" aria-hidden="true" />
          <div className="lp-section-head">
            <h2 id="lp-companions-title">One life. <em>More than one companion.</em></h2>
            <p>Different roles. Separate instructions and memory.</p>
          </div>
          <div className="lp-parallax" data-parallax><CompanionsScene /></div>
          <p className="lp-section-note">Separate instructions. Separate memory.</p>
        </section>

        <section className="lp-section lp-how" id="how" aria-labelledby="lp-how-title">
          <span className="lp-seam" aria-hidden="true" />
          <div className="lp-section-head">
            <h2 id="lp-how-title">Personal starts <em>with you.</em></h2>
            <p>Create a companion, share what matters, choose how it’s powered.</p>
          </div>
          <div className="lp-parallax" data-parallax><CreationPreview /></div>
          <ol className="lp-how-steps">
            <li className="lp-how-step">
              <span>01</span>
              <div><strong>Create your space.</strong><p>Sign up and set up your account.</p></div>
            </li>
            <li className="lp-how-step">
              <span>02</span>
              <div><strong>Shape your companion.</strong><p>Choose a name and instructions.</p></div>
            </li>
            <li className="lp-how-step">
              <span>03</span>
              <div><strong>Choose how it’s powered.</strong><p>Start with platform models, or connect your own provider.</p></div>
            </li>
          </ol>
        </section>

        <section className="lp-closing lp-section" id="closing" aria-labelledby="lp-closing-title">
          <span className="lp-seam" aria-hidden="true" />
          <span data-closing-reveal><CompanionMark /></span>
          <h2 id="lp-closing-title" data-closing-reveal>A little less to carry.<br /><em>A companion of your own.</em></h2>
          <p data-closing-reveal>One companion to start. More when you want them.</p>
          <div className="lp-closing-action" data-closing-reveal>
            <Link to={action.to} className="lp-button">
              {action.label}
              <ArrowUpRight size={17} aria-hidden="true" />
            </Link>
            {action.earlyAccess && <span>Early access · Account setup comes first</span>}
          </div>
          <p className="lp-availability" data-closing-reveal>
            Goal trackers on iPhone and iPad. Proactive help in development. <Link to="/capabilities">What’s available</Link>.
          </p>
        </section>
      </main>

      <LandingFooter signedIn={auth.signedIn} />
    </div>
  )
}
