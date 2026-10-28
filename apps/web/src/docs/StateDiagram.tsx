import { useEffect, useId, useRef, useState } from 'react'
import { cn } from '../lib/cn'
import type { LoopSpec } from './loops'

/**
 * A state diagram, drawn as a drafting sheet.
 *
 * Ported from the loop-designs benchmark: a trigger pill, state boxes, parked nodes
 * dashed because they wait on the world, a tinted exit node for the evidence "done"
 * rests on, arrowed edges, and a labelled loop-back edge that says what sends it
 * around again. The notation carries the semantics, which a list of chips could not.
 *
 * Routing rule, and the reason every edge misses every box:
 *
 *   A horizontal run only ever crosses a row *gap*, and a vertical run outside the
 *   node grid only ever uses a side lane. Nothing travels at a node's mid-height
 *   except the short in-row hop between neighbours.
 *
 * That gives three safe places to move: the gap below a row, the lanes at x = 14 and
 * x = 626 (the nodes span 28 to 612), and the band under everything. A loop-back uses
 * all three: down from its node into the gap, out to the descent lane, down to the
 * band, across, up the ascent lane, into the target's gap, and up into its underside.
 * Two lanes rather than one, or the descent and the ascent would lie on top of each
 * other.
 *
 * Departures from the benchmark, all fixes found by measuring the rendered geometry
 * rather than by looking at it:
 *   - The trigger pill is sized to its text and elbowed onto the first node. The
 *     reference forced it to one node's width, so a longer trigger spilled out of it.
 *   - The exit text wraps and the box grows to hold it. A single line ran past the
 *     rounded corners on any exit description over about 26 characters.
 *   - Edges cross below any self-loop bracket sharing their row. The reference routed
 *     straight through it.
 *   - A loop-back re-enters its target from underneath. The reference ran the final
 *     horizontal along the row's mid-height, which crossed every node between the
 *     lane and the target.
 *
 * Sized for the 40rem reading column so the SVG's own text renders at 1:1 rather than
 * being scaled into illegibility. Below that the figure scrolls sideways.
 */

const NW = 180 // node width
const NH = 50 // node height
const GAP = 22
// Wide enough that an edge crossing a row gap clears a self-loop bracket (30 deep)
// and still reaches the next row going downward, with room either side.
const ROWGAP = 58
const MX = 28 // side margin, which is also where a loop-back's lane runs
const PERROW = 3
const TRIGGER_H = 34
const BRACKET = 30 // depth of a self-loop bracket below its node
const VIEW_W = MX * 2 + PERROW * NW + (PERROW - 1) * GAP

const colX = (c: number) => MX + c * (NW + GAP)
const colCenter = (c: number) => colX(c) + NW / 2

type Placed = { x: number; y: number; col: number; row: number }

function place(count: number, rowsTop: number): Placed[] {
  return Array.from({ length: count }, (_, i) => ({
    x: colX(i % PERROW),
    y: rowsTop + Math.floor(i / PERROW) * (NH + ROWGAP),
    col: i % PERROW,
    row: Math.floor(i / PERROW),
  }))
}

/** Greedy word wrap, so an exit description fits the box instead of running past it. */
function wrap(text: string, maxChars: number): string[] {
  const lines: string[] = []
  let line = ''
  for (const word of text.split(' ')) {
    if (line && line.length + word.length + 1 > maxChars) {
      lines.push(line)
      line = word
    } else {
      line = line ? `${line} ${word}` : word
    }
  }
  if (line) lines.push(line)
  return lines
}

export default function StateDiagram({ spec, className }: { spec: LoopSpec; className?: string }) {
  const uid = useId().replace(/:/g, '')
  const { ref, seen } = useSeen()
  const [live, setLive] = useState(false)

  const nodes = spec.nodes
  const rows = Math.ceil(nodes.length / PERROW)
  const rowsTop = TRIGGER_H + 22
  const pos = place(nodes.length, rowsTop)
  const last = pos[pos.length - 1]

  // The exit box grows to hold a wrapped description. This has to resolve before any
  // y position is computed, since everything below it is stacked.
  const exitLines = spec.exit ? wrap(spec.exit, 24) : null
  const exitH = exitLines && exitLines.length > 1 ? NH + 16 : NH

  const lastRowCount = nodes.length - (rows - 1) * PERROW
  // The exit shares the last row when there is a free column, otherwise it takes one.
  const exitOwnRow = lastRowCount === PERROW

  const loopFrom = pos[spec.loop.from]
  const loopTo = pos[spec.loop.to]
  const selfLoop = spec.loop.from === spec.loop.to
  /**
   * A self-loop bracket hangs below its node. Any edge that has to run horizontally
   * across that row's gap would cut through it, so the crossing depth is decided per
   * row rather than per node.
   */
  const bracketInRow = (row: number) => selfLoop && loopFrom.row === row

  const exitX = exitOwnRow ? MX : colX(lastRowCount)
  const bracketBelow = bracketInRow(last.row) && exitOwnRow
  const exitY = exitOwnRow ? last.y + NH + ROWGAP + (bracketBelow ? 26 : 0) : last.y

  // The exit can be taller than a state node, so it sets the floor whether or not it
  // shares the last row. Using the node height here clipped a wrapped exit.
  const contentBottom = Math.max(last.y + NH, exitY + exitH)
  const bracketBottom = loopFrom.y + NH + BRACKET
  const bandY = contentBottom + 72
  // A self-loop lives entirely under its node, so a band below everything would be
  // empty space. The bracket still has to fit inside the viewBox.
  const viewH = selfLoop ? Math.max(contentBottom, bracketBottom) + 8 : bandY + 22

  const rowTop = (row: number) => rowsTop + row * (NH + ROWGAP)

  /** The lowest thing in a row: a wrapped exit in the last row can out-top a state node. */
  const rowBottom = (row: number) => {
    const nodesBottom = rowTop(row) + NH
    return !exitOwnRow && row === rows - 1 ? Math.max(nodesBottom, exitY + exitH) : nodesBottom
  }

  /**
   * A y inside the gap below a row, clear of anything hanging into it. Every
   * horizontal run in the diagram uses one of these, which is what keeps edges off
   * the boxes: a gap has no boxes in it by construction.
   */
  const gapBelow = (row: number) => rowBottom(row) + (bracketInRow(row) ? 38 : 22)

  /**
   * The loop-back crosses the same gaps as the row-wrap, so it takes a second lane
   * further down. On one shared y the two runs lie along each other wherever their
   * x-ranges meet, which reads as a mistake even though neither touches a box.
   */
  const loopGap = (row: number) => rowBottom(row) + (bracketInRow(row) ? 52 : 46)

  const triggerText = `TRIGGER · ${spec.trigger}`
  const triggerW = Math.min(VIEW_W - MX * 2, Math.max(NW, triggerText.length * 6.3 + 34))

  // Two lanes, chosen nearest each end and forced apart when they would coincide, or
  // the descent and ascent would overlap along a shared stretch.
  const leftLane = MX / 2
  const rightLane = VIEW_W - MX / 2
  const nearestLane = (centerX: number) => (centerX <= VIEW_W / 2 ? leftLane : rightLane)
  const fromCenter = loopFrom.x + NW / 2
  const toCenter = loopTo.x + NW / 2
  let descentLane = nearestLane(fromCenter)
  const ascentLane = nearestLane(toCenter)
  if (descentLane === ascentLane) descentLane = descentLane === leftLane ? rightLane : leftLane

  const arrow = `url(#${uid}-arrow)`
  const arrowAccent = `url(#${uid}-arrow-accent)`

  // A self-loop is a bracket hooked under its own node with its label inside it.
  // Keep its label under about twenty characters.
  const loopPath = selfLoop
    ? `M ${fromCenter - 62} ${loopFrom.y + NH} V ${loopFrom.y + NH + BRACKET} H ${fromCenter + 62} V ${loopFrom.y + NH + 4}`
    : [
        `M ${fromCenter} ${loopFrom.y + NH}`,
        `V ${loopGap(loopFrom.row)}`,
        `H ${descentLane}`,
        `V ${bandY}`,
        `H ${ascentLane}`,
        `V ${loopGap(loopTo.row)}`,
        `H ${toCenter}`,
        `V ${loopTo.y + NH + 4}`,
      ].join(' ')

  // Centred on the band's run, then pulled back inside the viewBox. A label hanging
  // off the right edge is silently cropped, which is worse than off-centre.
  const labelHalf = ((spec.loop.label.length + 2) * 6) / 2
  const bandMid = (descentLane + ascentLane) / 2
  const loopLabelX = selfLoop
    ? fromCenter
    : Math.min(Math.max(bandMid, labelHalf + 4), VIEW_W - labelHalf - 4)
  const loopLabelY = selfLoop ? loopFrom.y + NH + 20 : bandY - 7

  const edges: string[] = []
  edges.push(
    `M ${MX + triggerW / 2} ${TRIGGER_H} V ${TRIGGER_H + 11} H ${colCenter(0)} V ${pos[0].y - 7}`,
  )
  for (let i = 0; i < nodes.length - 1; i++) {
    const a = pos[i]
    const b = pos[i + 1]
    if (a.row === b.row) {
      edges.push(`M ${a.x + NW} ${a.y + NH / 2} H ${b.x - 7}`)
    } else {
      edges.push(`M ${a.x + NW / 2} ${a.y + NH} V ${gapBelow(a.row)} H ${b.x + NW / 2} V ${b.y - 7}`)
    }
  }
  edges.push(
    exitOwnRow
      ? `M ${last.x + NW / 2} ${last.y + NH} V ${gapBelow(last.row)} H ${exitX + NW / 2} V ${exitY - 7}`
      : `M ${last.x + NW} ${last.y + NH / 2} H ${exitX - 7}`,
  )

  // The travelling dot demonstrates the return rather than only labelling it. SMIL
  // because it follows the drawn path and scales with the viewBox; it starts when the
  // figure is first seen so it stays in step with the cascade.
  useEffect(() => {
    if (!seen || !ref.current) return
    setLive(true)
    ref.current
      .querySelectorAll('animateMotion')
      .forEach((m) => (m as SVGAnimationElement).beginElement?.())
  }, [seen, ref])

  return (
    <figure ref={ref} className={cn('dx-machine', seen && 'is-live', live && 'is-running', className)}>
      <div className="dx-machine-scroll">
        <svg
          viewBox={`0 0 ${VIEW_W} ${viewH}`}
          role="img"
          aria-label={`${spec.trigger} loop: ${nodes.map((n) => n.label).join(', then ')}. ${
            spec.exit ? `Exits on ${spec.exit}.` : 'No exit.'
          }`}
          className="dx-machine-svg"
        >
          <defs>
            <marker id={`${uid}-arrow`} viewBox="0 0 8 8" refX="7" refY="4" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
              <path className="dx-m-arrow" d="M0,0 L8,4 L0,8 z" />
            </marker>
            <marker id={`${uid}-arrow-accent`} viewBox="0 0 8 8" refX="7" refY="4" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
              <path className="dx-m-arrow-accent" d="M0,0 L8,4 L0,8 z" />
            </marker>
          </defs>

          <g className="dx-dnode dx-dtrigger">
            <rect x={MX} y={0} width={triggerW} height={TRIGGER_H} rx={17} />
            <text className="dx-dsmall" x={MX + 17} y={TRIGGER_H / 2 + 3.5}>
              {triggerText}
            </text>
          </g>

          {/* edges first, nodes on top, so a line never crosses a box */}
          {edges.map((d, i) => (
            <path key={i} className="dx-dedge" d={d} markerEnd={arrow} />
          ))}

          {nodes.map((node, i) => {
            const p = pos[i]
            return (
              <g
                key={node.label}
                className={cn('dx-dnode', node.parked ? 'dx-dparked' : 'dx-dstate')}
                style={{ '--i': i } as React.CSSProperties}
              >
                <rect x={p.x} y={p.y} width={NW} height={NH} rx={7} />
                <text
                  className="dx-dlabel"
                  x={p.x + NW / 2}
                  y={node.sub ? p.y + NH / 2 - 3 : p.y + NH / 2 + 4.5}
                  textAnchor="middle"
                >
                  {node.label}
                </text>
                {node.sub && (
                  <text className="dx-dsub" x={p.x + NW / 2} y={p.y + NH / 2 + 14} textAnchor="middle">
                    {node.sub}
                  </text>
                )}
              </g>
            )
          })}

          {/* the exit, or an explicit statement that the shape has none */}
          <g className={cn('dx-dnode', spec.exit ? 'dx-dexit' : 'dx-dexit dx-dnoexit')}>
            <rect x={exitX} y={exitY} width={NW} height={exitH} rx={16} />
            <text className="dx-dsmall" x={exitX + NW / 2} y={exitY + 19} textAnchor="middle">
              {spec.exit ? 'EXIT' : 'NO EXIT'}
            </text>
            {(exitLines ?? ['the user leads away']).map((line, i) => (
              <text
                key={line}
                className="dx-dlabel"
                x={exitX + NW / 2}
                y={exitY + 36 + i * 15}
                textAnchor="middle"
                fontSize={11.5}
              >
                {line}
              </text>
            ))}
          </g>

          {/* the loop-back, last so it sits over the band */}
          <path className="dx-dloop" d={loopPath} markerEnd={arrowAccent} />
          <text className="dx-dlooplabel" x={loopLabelX} y={loopLabelY} textAnchor="middle">
            ↻ {spec.loop.label}
          </text>
          <circle className="dx-dloopdot" r={4}>
            <animateMotion dur="2.4s" begin="indefinite" fill="freeze" path={loopPath} />
          </circle>
        </svg>
      </div>

      {/* Keyed to what this diagram actually uses, so the notation explains itself
          without a legend repeated on every page. */}
      <ul className="dx-machine-key">
        <li>
          <i className="dx-k dx-k-trigger" aria-hidden="true" />
          trigger
        </li>
        <li>
          <i className="dx-k dx-k-state" aria-hidden="true" />
          state
        </li>
        {nodes.some((n) => n.parked) && (
          <li>
            <i className="dx-k dx-k-parked" aria-hidden="true" />
            parked, waiting on the world
          </li>
        )}
        <li>
          <i className={cn('dx-k', spec.exit ? 'dx-k-exit' : 'dx-k-noexit')} aria-hidden="true" />
          {spec.exit ? 'exit, on evidence' : 'no exit'}
        </li>
        <li>
          <i className="dx-k dx-k-loop" aria-hidden="true" />
          loop back
        </li>
      </ul>

      {spec.handoffs && spec.handoffs.length > 0 && (
        <p className="dx-handoffs">
          {spec.handoffs.map((h) => (
            <span key={h.to} className="dx-handoff">
              <b>{h.to}</b> {h.when}
            </span>
          ))}
        </p>
      )}
    </figure>
  )
}

/** Fires once, the first time the figure is scrolled into view. */
function useSeen<T extends HTMLElement>() {
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
