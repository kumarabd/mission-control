import { cloneElement, isValidElement, useEffect, useRef, useState, type ReactNode } from 'react'
import { Link, useParams } from 'react-router-dom'
import Markdown, { type Components } from 'react-markdown'
import remarkGfm from 'remark-gfm'
import { ArrowLeft, ArrowRight, CircleHelp, Info, Link2, RefreshCw as LoopMark, TriangleAlert } from 'lucide-react'
import { cn } from '../lib/cn'
import DiagramFigure from './Diagram'
import StateDiagram from './StateDiagram'
import { DIAGRAMS, signatureIcon } from './diagrams'
import { LOOPS } from './loops'
import { findDoc, headingsOf, neighbours, slugify } from './loader'

function textOf(node: ReactNode): string {
  if (typeof node === 'string' || typeof node === 'number') return String(node)
  if (Array.isArray(node)) return node.map(textOf).join('')
  if (isValidElement(node)) return textOf((node.props as { children?: ReactNode }).children)
  return ''
}

function Anchor({ id, children }: { id: string; children: ReactNode }) {
  return (
    <>
      <a className="dx-anchor" href={`#${id}`} aria-label="Link to this section">
        <Link2 aria-hidden="true" />
      </a>
      {children}
    </>
  )
}

/**
 * A callout, written as `> [!NOTE] ...` in markdown.
 *
 * No plugin and no directive parser: remark hands the blockquote through as
 * ordinary children, so the marker is just the first line of the first paragraph.
 * GitHub's alert syntax was chosen because it degrades to a readable blockquote
 * in every other markdown viewer, including the raw file on disk.
 */
// Leading whitespace is tolerated because markdown hands the blockquote a text node
// holding the newline before the marker, ahead of the paragraph itself.
//
// NOTE and WARNING are GitHub's own alerts and degrade to a plain blockquote there.
// QUESTION is ours, for the open design questions a draft page collects; in a viewer
// that does not know it the marker stays visible, which is a legible outcome anyway.
const CALLOUT = /^\s*\[!(NOTE|WARNING|QUESTION)\]\s*/i

const CALLOUT_KINDS = {
  NOTE: { label: 'Note', icon: Info },
  WARNING: { label: 'Warning', icon: TriangleAlert },
  QUESTION: { label: 'Open question', icon: CircleHelp },
} as const

function Callout({ children }: { children: ReactNode }) {
  const list = (Array.isArray(children) ? children : [children]).filter(
    (child) => !(typeof child === 'string' && child.trim() === ''),
  )
  const [lead, ...rest] = list
  const match = isValidElement(lead) ? CALLOUT.exec(textOf(lead)) : null
  if (!match) return <blockquote>{children}</blockquote>

  const kind = match[1].toUpperCase() as keyof typeof CALLOUT_KINDS
  const { label, icon: Icon } = CALLOUT_KINDS[kind]

  // Strip the marker from the opening paragraph's first real text run, so any
  // emphasis later in the same paragraph survives.
  const kids = (lead.props as { children?: ReactNode }).children
  const patched = Array.isArray(kids) ? [...kids] : [kids]
  const at = patched.findIndex((child) => typeof child === 'string' && child.trim() !== '')
  if (at !== -1) patched[at] = (patched[at] as string).replace(CALLOUT, '')

  return (
    <aside className={cn('dx-callout', `dx-callout-${kind.toLowerCase()}`)}>
      <p className="dx-callout-label">
        <Icon aria-hidden="true" />
        {label}
      </p>
      {cloneElement(lead, undefined, ...patched)}
      {rest}
    </aside>
  )
}

/**
 * A fenced ```loop block becomes a state diagram, so a page with eleven of them
 * stays ordinary markdown rather than becoming a bespoke React page:
 *
 *     ```loop
 *     diagnose
 *     ```
 *
 * Same trick as the callout: override a markdown construct rather than teach the
 * loader a directive syntax.
 */
function LoopFence({ children }: { children: ReactNode }) {
  const code = isValidElement(children) ? children : null
  const className = code ? ((code.props as { className?: string }).className ?? '') : ''
  if (!/language-loop\b/.test(className)) return null

  const id = textOf((code!.props as { children?: ReactNode }).children).trim()
  const spec = LOOPS[id]
  if (!spec) {
    if (import.meta.env.DEV) console.warn(`docs: no loop spec named "${id}"`)
    return null
  }
  return <StateDiagram spec={spec} />
}

const components: Components = {
  blockquote: ({ children }) => <Callout>{children as ReactNode[]}</Callout>,
  pre: ({ children, ...props }) => {
    const isLoop = isValidElement(children) && /language-loop\b/.test(((children.props as { className?: string }).className ?? ''))
    return isLoop ? <LoopFence>{children}</LoopFence> : <pre {...props}>{children}</pre>
  },
  h2: ({ children, ...props }) => {
    const id = slugify(textOf(children))
    return (
      <h2 id={id} data-dx-heading {...props}>
        <Anchor id={id}>{children}</Anchor>
      </h2>
    )
  },
  h3: ({ children, ...props }) => {
    const id = slugify(textOf(children))
    return (
      <h3 id={id} data-dx-heading {...props}>
        <Anchor id={id}>{children}</Anchor>
      </h3>
    )
  },
  // Internal links navigate; external ones leave. A docs page is a place people
  // move around inside, so a full reload on every cross-reference is wrong.
  a: ({ href = '', children, className, ...props }) => {
    if (href.startsWith('/') && !href.startsWith('//')) {
      return (
        <Link to={href} className={cn('dx-md-link', className)}>
          {children}
        </Link>
      )
    }
    return (
      <a href={href} className={cn('dx-md-link', className)} target="_blank" rel="noreferrer" {...props}>
        {children}
      </a>
    )
  },
}

/**
 * Tracks which heading the reader is level with. Driven by an IntersectionObserver
 * rather than a scroll listener, and resolved by position on each callback so a fast
 * scroll cannot leave two headings claiming to be current.
 */
function useActiveHeading(slug: string | undefined, deps: unknown[]) {
  const ref = useRef<HTMLElement>(null)
  const [active, setActive] = useState('')

  useEffect(() => {
    const root = ref.current
    if (!root) return
    const nodes = Array.from(root.querySelectorAll<HTMLElement>('[data-dx-heading]'))
    if (nodes.length === 0) return

    const sync = () => {
      const line = window.innerHeight * 0.3
      // Empty until the reader is level with the first heading: marking the first
      // section current while they are still in the intro is a lie.
      let current = ''
      for (const node of nodes) {
        if (node.getBoundingClientRect().top <= line) current = node.id
      }
      setActive(current)
    }

    const observer = new IntersectionObserver(sync, { rootMargin: '-10% 0px -60% 0px' })
    nodes.forEach((node) => observer.observe(node))
    sync()
    return () => observer.disconnect()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [slug, ...deps])

  return { ref, active }
}

export default function DocsArticle() {
  // A splat route, because a doc's slug is its path under /docs and can be nested
  // (docs/architecture/topology.md → "architecture/topology").
  const slug = useParams()['*'] ?? ''
  const doc = findDoc(slug)
  const diagram = DIAGRAMS[slug]
  const related = (doc?.related ?? []).flatMap((target) => {
    const page = findDoc(target)
    if (!page) {
      if (import.meta.env.DEV) console.warn(`docs: "${slug}" lists related page "${target}", which does not exist`)
      return []
    }
    // A page with no lead figure of its own, such as a loop shape, still gets a chip.
    const spec = DIAGRAMS[target]
    return [{ slug: target, title: page.title, icon: spec ? signatureIcon(spec) : LoopMark }]
  })
  const headings = doc ? headingsOf(doc.body) : []
  const { prev, next } = doc ? neighbours(doc.slug) : {}
  const { ref, active } = useActiveHeading(slug, [headings.length])

  useEffect(() => {
    document.title = doc ? `${doc.title} · MissionControl Docs` : 'Not found · MissionControl Docs'
    window.scrollTo(0, 0)
  }, [doc])

  if (!doc) {
    return (
      <main className="dx-main">
        <article className="dx-doc">
          <div className="dx-missing">
            <h1>No page at that address.</h1>
            <p className="dx-hero-lead">
              It may have been renamed. The index lists everything that is published.
            </p>
            <Link to="/docs" className="dx-close-link">
              Back to documentation
              <ArrowRight aria-hidden="true" />
            </Link>
          </div>
        </article>
      </main>
    )
  }

  return (
    <>
      <main className="dx-main">
        <article className="dx-doc" ref={ref}>
          <header className="dx-doc-head">
            <h1>{doc.title}</h1>
            {doc.status && <p className="dx-status">{doc.status}</p>}
            {doc.summary && <p className="dx-hero-lead">{doc.summary}</p>}
          </header>

          {diagram && <DiagramFigure diagram={diagram} />}

          <div className="dx-prose">
            <Markdown remarkPlugins={[remarkGfm]} components={components}>
              {doc.body}
            </Markdown>
          </div>

          {related.length > 0 && (
            <nav className="dx-related" aria-label="Related pages">
              <p className="dx-related-label">Related</p>
              <div className="dx-related-list">
                {related.map((target) => (
                  <Link key={target.slug} to={`/docs/${target.slug}`} className="dx-related-link">
                    <target.icon aria-hidden="true" />
                    {target.title}
                  </Link>
                ))}
              </div>
            </nav>
          )}

          {(prev || next) && (
            <nav className="dx-pager" aria-label="Documentation">
              {prev ? (
                <Link to={`/docs/${prev.slug}`} className="dx-pager-link dx-pager-prev">
                  <span className="dx-pager-dir">
                    <ArrowLeft aria-hidden="true" /> Previous
                  </span>
                  <span className="dx-pager-title">{prev.title}</span>
                </Link>
              ) : (
                <span />
              )}
              {next && (
                <Link to={`/docs/${next.slug}`} className="dx-pager-link dx-pager-next">
                  <span className="dx-pager-dir">
                    Next <ArrowRight aria-hidden="true" />
                  </span>
                  <span className="dx-pager-title">{next.title}</span>
                </Link>
              )}
            </nav>
          )}
        </article>
      </main>

      {headings.length > 1 && (
        <aside className="dx-toc" aria-label="On this page">
          <p className="dx-toc-label">On this page</p>
          <ul className="dx-toc-list">
            {headings.map((heading) => (
              <li key={heading.id} className={cn('dx-toc-item', heading.depth === 3 && 'dx-toc-sub')}>
                <a
                  href={`#${heading.id}`}
                  className={cn('dx-toc-link', active === heading.id && 'dx-toc-link-on')}
                >
                  {heading.text}
                </a>
              </li>
            ))}
          </ul>
        </aside>
      )}
    </>
  )
}
