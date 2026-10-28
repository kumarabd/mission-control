import { useRef } from 'react'
import { ArrowUpRight } from 'lucide-react'
import { useExplorerAuth } from '../auth/context'
import { LandingFooter, LandingHeader } from '../features/landing/Chrome'
import { landingAction } from '../features/landing/model'
import { usePageMeta } from '../features/landing/meta'
import '../features/landing/landing.css'

// The pitch deck is a self-contained page (public/decks/mission-control.html) so it can also be opened and presented on its own.
const DECK = '/decks/mission-control.html'

export default function Slides() {
  const auth = useExplorerAuth()
  const action = landingAction(auth)
  const frame = useRef<HTMLIFrameElement>(null)

  usePageMeta('Slides — Mission Control', 'What Mission Control is, why it exists and how it works, in ten animated slides.')

  return (
    <div className="lp lp-info-page">
      <a className="lp-skip" href="#slides-main">Skip to content</a>
      <LandingHeader action={action} onHome={false} />
      <main className="lp-slides" id="slides-main">
        <div className="lp-slides-head">
          <h1>Mission Control, <em>in ten slides.</em></h1>
          <p>What it is, why it exists, and how it works.</p>
        </div>
        <div className="lp-slides-frame">
          <iframe ref={frame} src={DECK} title="Mission Control slides" allow="fullscreen" allowFullScreen loading="lazy" />
        </div>
        <div className="lp-slides-bar">
          <a href={DECK} target="_blank" rel="noreferrer" className="lp-button lp-button-small">
            Present full screen
            <ArrowUpRight size={15} aria-hidden="true" />
          </a>
          <span>Click a slide, then use the arrow keys · N for notes · F for full screen</span>
        </div>
      </main>
      <LandingFooter signedIn={auth.signedIn} />
    </div>
  )
}
