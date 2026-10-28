import { useRef, type ReactNode } from 'react'
import { useExplorerAuth } from '../../auth/context'
import { landingAction } from './model'
import { LandingFooter, LandingHeader } from './Chrome'
import { useInfoMotion } from './motion'
import { usePageMeta } from './meta'
import './landing.css'

export function InfoLayout({ title, description, children }: { title: string; description: string; children: ReactNode }) {
  const root = useRef<HTMLDivElement>(null)
  const auth = useExplorerAuth()
  const action = landingAction(auth)
  useInfoMotion(root)

  usePageMeta(`${title} — Mission Control`, description)

  return (
    <div className="lp lp-info-page" ref={root}>
      <div className="lp-reading-progress" aria-hidden="true" />
      <a className="lp-skip" href="#info-main">Skip to content</a>
      <LandingHeader action={action} onHome={false} />
      <main className="lp-info-main" id="info-main">
        {children}
      </main>
      <LandingFooter signedIn={auth.signedIn} />
    </div>
  )
}
