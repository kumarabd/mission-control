import { useState } from 'react'
import { Link, NavLink, Outlet, useLocation } from 'react-router-dom'
import { Menu, Search } from 'lucide-react'
import ThemeSwitcher from '../components/ThemeSwitcher'
import { Input } from '../components/ui'
import { cn } from '../lib/cn'
import { DOC_GROUPS, DOCS, type Doc } from './loader'
import '../docs/docs.css'

/**
 * The reading rail. Each doc is a tick on a single unbroken spine, and the current
 * one lights its segment. The line is the navigation, not decoration: it is what
 * makes "where am I in the argument" readable at a glance.
 */
function DocsRail({ onNavigate }: { onNavigate: () => void }) {
  const { pathname } = useLocation()
  const [query, setQuery] = useState('')
  const needle = query.trim().toLowerCase()
  const matches = (doc: Doc) =>
    !needle || doc.title.toLowerCase().includes(needle) || doc.summary.toLowerCase().includes(needle)

  // A filter searches the children too, and a matching child keeps its parent on screen.
  const groups = DOC_GROUPS.map((group) => ({
    label: group.label,
    entries: group.entries
      .map((entry) => ({ doc: entry.doc, children: entry.children.filter(matches) }))
      .filter((entry) => matches(entry.doc) || entry.children.length > 0),
  })).filter((group) => group.entries.length > 0)

  return (
    <>
      <div className="dx-rail-head">
        <Input
          inputSize="sm"
          iconLeft={<Search />}
          value={query}
          onChange={(event) => setQuery(event.target.value)}
          placeholder="Filter"
          aria-label="Filter documents"
        />
      </div>

      <div className="dx-spine">
        {groups.map((group) => (
          <section key={group.label} className="dx-group">
            <h2 className="dx-group-label">{group.label}</h2>
            <ul className="dx-list">
              {group.entries.map((entry) => {
                // A parent stays lit while you are anywhere in its family, and only
                // then do its children show: eleven loop pages would otherwise push
                // every later group off the rail.
                const inFamily = pathname === `/docs/${entry.doc.slug}` || pathname.startsWith(`/docs/${entry.doc.slug}/`)
                return (
                  <li key={entry.doc.slug}>
                    <NavLink
                      to={`/docs/${entry.doc.slug}`}
                      onClick={onNavigate}
                      className={cn('dx-link', inFamily && 'dx-link-on')}
                    >
                      <span className="dx-tick" aria-hidden="true" />
                      <span className="dx-link-text">{entry.doc.title}</span>
                      {entry.children.length > 0 && (
                        <span className="dx-count" aria-hidden="true">
                          {entry.children.length}
                        </span>
                      )}
                    </NavLink>
                    {entry.children.length > 0 && inFamily && (
                      <ul className="dx-sublist">
                        {entry.children.map((child) => (
                          <li key={child.slug}>
                            <NavLink
                              to={`/docs/${child.slug}`}
                              onClick={onNavigate}
                              className={({ isActive }) => cn('dx-link', 'dx-link-child', isActive && 'dx-link-on')}
                            >
                              <span className="dx-link-text">{child.title}</span>
                            </NavLink>
                          </li>
                        ))}
                      </ul>
                    )}
                  </li>
                )
              })}
            </ul>
          </section>
        ))}
        {groups.length === 0 && (
          <p className="dx-rail-empty">
            Nothing matches “{query.trim()}”. <Link to="/docs">Show all {DOCS.length}</Link>
          </p>
        )}
      </div>
    </>
  )
}

export default function DocsLayout() {
  // Only meaningful below 1024px, where the rail is a disclosure rather than a
  // column. The rail's own links close it, so a tap lands on the article.
  const [navOpen, setNavOpen] = useState(false)

  return (
    <div className="dx">
      <div className="dx-progress" aria-hidden="true" />

      <header className="dx-bar">
        <Link to="/" className="dx-brand">
          <img src="/logo-mark.svg" alt="" width={22} height={22} />
          <span>MissionControl</span>
          <span className="dx-brand-tag">Docs</span>
        </Link>

        <div className="dx-bar-actions">
          <button
            type="button"
            className="dx-navtoggle"
            aria-expanded={navOpen}
            aria-controls="dx-rail"
            onClick={() => setNavOpen((open) => !open)}
          >
            <Menu aria-hidden="true" />
            <span>Contents</span>
          </button>
          <Link to="/" className="dx-bar-link">
            Home
          </Link>
          <ThemeSwitcher />
        </div>
      </header>

      <div className="dx-shell">
        <nav id="dx-rail" className={cn('dx-rail', navOpen && 'dx-rail-open')} aria-label="Documentation">
          <DocsRail onNavigate={() => setNavOpen(false)} />
        </nav>

        <Outlet />
      </div>
    </div>
  )
}
