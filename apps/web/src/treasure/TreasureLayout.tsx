import { useEffect } from 'react'
import { Link, NavLink, Outlet, useLocation } from 'react-router-dom'
import './treasure.css'
import { CONTACT_EMAIL, OPERATOR } from './site'

/** Fades elements in as they scroll into view. Re-scans on every route change. */
function useReveal(key: string) {
  useEffect(() => {
    const items = Array.from(document.querySelectorAll<HTMLElement>('.tr [data-reveal]'))
    if (!('IntersectionObserver' in window)) { items.forEach((el) => el.classList.add('in')); return }
    const io = new IntersectionObserver(
      (entries) => entries.forEach((e) => { if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target) } }),
      { threshold: 0.12, rootMargin: '0px 0px -6% 0px' },
    )
    items.forEach((el) => io.observe(el))
    return () => io.disconnect()
  }, [key])
}

export default function TreasureLayout() {
  const { pathname } = useLocation()
  useReveal(pathname)
  useEffect(() => { window.scrollTo(0, 0) }, [pathname])

  return (
    <div className="tr">
      <header className="tr-nav">
        <div className="wrap">
          <Link to="/treasure" className="tr-brand" aria-label="Treasure home">
            <img src="/treasure-icon.png" alt="" width={30} height={30} />
            Treasure
          </Link>
          <nav className="tr-links" aria-label="Treasure">
            <NavLink to="/treasure" end className="keep">Overview</NavLink>
            <NavLink to="/treasure/support" className="keep">Support</NavLink>
            <NavLink to="/treasure/privacy">Privacy</NavLink>
          </nav>
        </div>
      </header>

      <main><Outlet /></main>

      <footer className="tr-foot">
        <div className="wrap">
          <span>© {new Date().getFullYear()} {OPERATOR}. Treasure is for iPhone.</span>
          <nav aria-label="Legal">
            <Link to="/treasure/support">Support</Link>
            <Link to="/treasure/privacy">Privacy Policy</Link>
            <a href={`mailto:${CONTACT_EMAIL}`}>Contact</a>
          </nav>
        </div>
      </footer>
    </div>
  )
}
