import { useEffect, useRef, useState, type CSSProperties } from 'react'
import { cn } from '../lib/cn'
import StateDiagram from './StateDiagram'
import type { Diagram, DiagramSide } from './diagrams'

/**
 * The lead figure on a doc.
 *
 * Two dispatches, because there are two kinds of thing to draw: a process, which
 * goes to the state-diagram notation, and a structure, which does not have steps
 * or an exit and is drawn as regions instead.
 */

function useSeenOnce<T extends HTMLElement>() {
  const ref = useRef<T>(null)
  const [seen, setSeen] = useState(false)

  useEffect(() => {
    const element = ref.current
    if (!element || seen) return
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => entry.isIntersecting)) setSeen(true)
      },
      { rootMargin: '0px 0px -10% 0px' },
    )
    observer.observe(element)
    return () => observer.disconnect()
  }, [seen])

  return { ref, seen }
}

function Region({ side, index }: { side: DiagramSide; index: number }) {
  return (
    <section
      className={cn('dx-region', side.tone === 'accent' && 'dx-region-accent')}
      style={{ '--i': index } as CSSProperties}
    >
      <h3 className="dx-region-title">
        <span className="dx-region-icon" aria-hidden="true">
          <side.icon />
        </span>
        {side.title}
      </h3>
      <ul className="dx-region-list">
        {side.items.map((item) => (
          <li key={item}>{item}</li>
        ))}
      </ul>
    </section>
  )
}

function Regions({ sides, nested, boundary }: { sides: DiagramSide[]; nested?: boolean; boundary?: string }) {
  if (nested && sides.length >= 2) {
    // sides[0] is what the boundary encloses; sides[1] sits outside it.
    return (
      <div className="dx-regions dx-regions-nested">
        <div className="dx-boundary">
          <span className="dx-boundary-label">{boundary ?? 'Your boundary'}</span>
          <Region side={sides[0]} index={0} />
        </div>
        <Region side={sides[1]} index={1} />
      </div>
    )
  }

  return (
    <div className="dx-regions">
      {sides.map((side, index) => (
        <Region key={side.title} side={side} index={index} />
      ))}
    </div>
  )
}

export default function DiagramFigure({ diagram }: { diagram: Diagram }) {
  const { ref, seen } = useSeenOnce<HTMLElement>()

  if (diagram.shape === 'machine') {
    return (
      <figure className="dx-fig">
        <StateDiagram spec={diagram.spec} />
        <figcaption className="dx-fig-cap">{diagram.caption}</figcaption>
      </figure>
    )
  }

  return (
    <figure ref={ref} className={cn('dx-fig', seen && 'is-live')}>
      <Regions sides={diagram.sides} nested={diagram.nested} boundary={diagram.boundary} />
      <figcaption className="dx-fig-cap">{diagram.caption}</figcaption>
    </figure>
  )
}
