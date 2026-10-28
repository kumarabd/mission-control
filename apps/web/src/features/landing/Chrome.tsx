import { useEffect, useRef, type ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { ArrowUpRight } from 'lucide-react'
import ThemeSwitcher from '../../components/ThemeSwitcher'

type Action = { label: string; to: string }

function NavAnchor({ hash, onHome, children }: { hash: string; onHome: boolean; children: ReactNode }) {
  return onHome
    ? <a href={hash}>{children}</a>
    : <Link to={`/${hash}`}>{children}</Link>
}

export function LandingHeader({ action, onHome = true, showAction = true }: { action: Action; onHome?: boolean; showAction?: boolean }) {
  const ref = useRef<HTMLElement>(null)

  // The header steps out of the way while the story is being read and comes
  // back the moment the visitor scrolls up. Reduced motion keeps it fixed.
  useEffect(() => {
    if (typeof matchMedia === 'function' && matchMedia('(prefers-reduced-motion: reduce)').matches) return
    const node = ref.current
    if (!node) return

    let last = window.scrollY
    let frame = 0
    const update = () => {
      frame = 0
      const y = window.scrollY
      node.classList.toggle('lp-header-scrolled', y > 12)
      if (Math.abs(y - last) < 6) return
      node.classList.toggle('lp-header-hidden', y > last && y > 160)
      last = y
    }
    const onScroll = () => {
      if (!frame) frame = requestAnimationFrame(update)
    }

    update()
    const reveal = () => node.classList.remove('lp-header-hidden')
    node.addEventListener('focusin', reveal)
    window.addEventListener('scroll', onScroll, { passive: true })
    return () => {
      node.removeEventListener('focusin', reveal)
      window.removeEventListener('scroll', onScroll)
      if (frame) cancelAnimationFrame(frame)
    }
  }, [])

  return (
    <header className="lp-header" ref={ref}>
      <Link to="/" className="lp-brand" aria-label="Mission Control home">
        <img src="/logo-mark.svg" width="26" height="26" alt="" />
        <span>Mission Control</span>
      </Link>
      <nav aria-label="Explore Mission Control">
        <NavAnchor hash="#why" onHome={onHome}>Why it’s yours</NavAnchor>
        <NavAnchor hash="#what" onHome={onHome}>What it does</NavAnchor>
        <NavAnchor hash="#companions" onHome={onHome}>Companions</NavAnchor>
        <Link to="/slides">Slides</Link>
      </nav>
      {showAction && (
        <Link to={action.to} className="lp-button lp-button-small">
          {action.label}
          <ArrowUpRight size={15} aria-hidden="true" />
        </Link>
      )}
    </header>
  )
}

export function LandingFooter({ signedIn }: { signedIn: boolean }) {
  return (
    <footer className="lp-footer">
      <Link to="/" className="lp-brand">
        <img src="/logo-mark.svg" width="23" height="23" alt="" />
        Mission Control
      </Link>
      <div>
        <Link to="/docs">Documentation</Link>
        <Link to="/slides">Slides</Link>
        <Link to="/privacy">Privacy</Link>
        <Link to="/support">Support</Link>
        <Link to="/capabilities">What’s available</Link>
        {!signedIn && <Link to="/login">Log in</Link>}
        <ThemeSwitcher className="lp-theme-switch" />
      </div>
      <p>Personal assistants and companions. Shaped by you.</p>
    </footer>
  )
}
