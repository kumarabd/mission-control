import { useEffect } from 'react'
import { Link } from 'react-router-dom'
import { ArrowRight } from 'lucide-react'
import DiagramFigure from './Diagram'
import { INDEX_DIAGRAM } from './diagrams'
import { DOC_GROUPS, DOCS } from './loader'

/**
 * The index is the one place on this surface with an authored entrance, because it
 * is the one screen a reader sees rarely. Everything inside an article holds still:
 * prose the reader is working through is not a thing to move under them.
 *
 * The rows carry the same tick-on-a-spine mark as the rail, so arriving here reads
 * as moving along one document rather than opening a different site.
 */
export default function DocsIndex() {
  useEffect(() => {
    document.title = 'Documentation · MissionControl'
  }, [])

  const first = DOCS[0]

  return (
    <main className="dx-main">
      <article className="dx-doc dx-index">
        <header className="dx-hero">
          <h1 className="dx-hero-title">How MissionControl works.</h1>
          <p className="dx-hero-lead">
            The ideas behind the agent, and the architecture it runs on. Read in
            order, or dip into whichever one you need.
          </p>
          <DiagramFigure diagram={INDEX_DIAGRAM} />
        </header>

        {DOC_GROUPS.map((group, groupAt) => (
          <section key={group.label} className="dx-group-block">
            <h2 className="dx-block-label">{group.label}</h2>
            <ul className="dx-cards">
              {group.entries.map(({ doc, children }, docAt) => (
                <li
                  key={doc.slug}
                  className="dx-card"
                  style={{ '--dx-i': groupAt * 3 + docAt } as React.CSSProperties}
                >
                  <Link to={`/docs/${doc.slug}`} className="dx-card-link">
                    <span className="dx-tick" aria-hidden="true" />
                    <span className="dx-card-body">
                      <span className="dx-card-title">
                        {doc.title}
                        {/* The count, not the eleven: this page is an index, and the
                            section's own page is where the family is laid out. */}
                        {children.length > 0 && <span className="dx-card-count">{children.length}</span>}
                      </span>
                      {doc.summary && <span className="dx-card-summary">{doc.summary}</span>}
                    </span>
                    <ArrowRight className="dx-card-go" aria-hidden="true" />
                  </Link>
                </li>
              ))}
            </ul>
          </section>
        ))}

        {/* The close resolves rather than trailing into nothing. */}
        <footer className="dx-close">
          <p className="dx-close-line">
            New here? The agent is the right place to start.
          </p>
          {first && (
            <Link to={`/docs/${first.slug}`} className="dx-close-link">
              Read {first.title}
              <ArrowRight aria-hidden="true" />
            </Link>
          )}
        </footer>
      </article>
    </main>
  )
}
