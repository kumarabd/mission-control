import { useCallback, useEffect, useMemo, useRef, useState, type CSSProperties } from 'react'
import { Maximize2, Minus, Plus } from 'lucide-react'
import { animate, spring } from 'animejs'
import { ExtensionCategory, Graph, register } from '@antv/g6'
import { ReactNode as G6ReactNode } from '@antv/g6-extension-react'
import type { SemanticWorldGraph, WorldEdge, WorldNode } from '../../lib/types'
import { IconButton } from '../ui'
import { WORLD_MONO } from './worldGraphShapes'
import { WorldMark } from './worldGraphMarks'
import type { WorldGraphTokens } from './worldGraphTokens'

/**
 * G6 v5 draws the graph and owns layout, pan/zoom, node dragging and the
 * animated transitions. React renders the Living Atlas marks and the
 * isolated-entity shelf, so the web keeps the same shape grammar as the native
 * clients instead of falling back to dots and labels.
 */

const NODE_W = 140
const NODE_H = 90

type GraphNodeData = {
  node: WorldNode
  color: string
  selected: boolean
  dimmed: boolean
  degree: number
}

type GraphEdgeData = {
  edge: WorldEdge
  active: boolean
  dragActive?: boolean
  labelVisible: boolean
  dimmed: boolean
  pairIndex: number
  pairCount: number
}

type DragNode = {
  id: string
  dragWeight: number
  releaseWeight: number
  start: [number, number]
}

type DragSession = {
  id: string
  nodes: DragNode[]
  startClientX: number
  startClientY: number
  totalX: number
  totalY: number
  active: boolean
  frame: number
}

type NodeDatum = { id: string; data: GraphNodeData }

register(ExtensionCategory.NODE, 'react', G6ReactNode as never)

export default function WorldGraphG6({
  graph,
  selectedId,
  onSelect,
  typeColor,
  tokens,
}: {
  graph: SemanticWorldGraph
  selectedId: string | null
  onSelect: (id: string | null) => void
  typeColor: (type?: string) => string
  tokens: WorldGraphTokens
}) {
  const frame = useRef<HTMLDivElement>(null)
  const graphRef = useRef<Graph | null>(null)
  const selectedRef = useRef(selectedId)
  const dragRef = useRef<DragSession | null>(null)
  const settleRef = useRef<ReturnType<typeof animate> | null>(null)
  const lastDragEnd = useRef(0)
  const suppressClick = useRef(false)
  const [ready, setReady] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    selectedRef.current = selectedId
  }, [selectedId])

  const elements = useMemo(
    () => buildElements(graph, selectedId, typeColor),
    [graph, selectedId, typeColor],
  )
  const elementsRef = useRef(elements)
  useEffect(() => {
    elementsRef.current = elements
  }, [elements])
  const hasNodes = elements.nodes.length > 0

  const paintNodeDrag = useCallback((dragged: string | null, neighbors: Set<string>) => {
    const container = frame.current
    if (!container) return
    container.querySelectorAll<HTMLElement>('.world-graph-node').forEach((element) => {
      const id = element.dataset.nodeId
      element.dataset.dragging = id === dragged ? 'true' : 'false'
      element.dataset.neighbor = id && id !== dragged && neighbors.has(id) ? 'true' : 'false'
    })
  }, [])

  const highlightDragEdges = useCallback((id: string | null) => {
    const instance = graphRef.current
    if (!instance) return
    if (id) {
      const related = new Set(instance.getRelatedEdgesData(id).map((edge) => String(edge.id)))
      instance.updateEdgeData(
        elementsRef.current.edges.map((edge) => ({
          id: edge.id,
          data: { ...edge.data, dragActive: related.has(edge.id), labelVisible: false },
        })),
      )
    } else {
      instance.updateEdgeData(elementsRef.current.edges.map((edge) => ({ id: edge.id, data: { ...edge.data, dragActive: false } })))
    }
    void instance.draw()
  }, [])

  const beginNodeDrag = useCallback((id: string, clientX: number, clientY: number) => {
    const instance = graphRef.current
    if (!instance) return
    settleRef.current?.cancel()
    settleRef.current = null
    if (dragRef.current?.frame) window.cancelAnimationFrame(dragRef.current.frame)
    suppressClick.current = false
    paintNodeDrag(null, new Set())
    highlightDragEdges(null)

    const weights = new Map<string, { drag: number; release: number }>([[id, { drag: 1, release: 1 }]])
    const direct = instance
      .getNeighborNodesData(id)
      .map((node) => String(node.id))
      .filter((neighbor) => neighbor !== id)
    for (const neighbor of direct) weights.set(neighbor, { drag: 0.6, release: 1 })
    const second = new Set<string>()
    for (const neighbor of direct) {
      for (const node of instance.getNeighborNodesData(neighbor)) {
        const other = String(node.id)
        if (other !== id && !weights.has(other)) second.add(other)
      }
    }
    for (const other of second) {
      if (weights.size >= 40) break
      weights.set(other, { drag: 0.28, release: 0.6 })
    }

    const nodes = [...weights.entries()].map(([nodeId, weight]) => {
      const position = instance.getElementPosition(nodeId)
      return {
        id: nodeId,
        dragWeight: weight.drag,
        releaseWeight: weight.release,
        start: [Number(position[0]) || 0, Number(position[1]) || 0] as [number, number],
      }
    })
    dragRef.current = {
      id,
      nodes,
      startClientX: clientX,
      startClientY: clientY,
      totalX: 0,
      totalY: 0,
      active: false,
      frame: 0,
    }
  }, [highlightDragEdges, paintNodeDrag])

  const moveNodeDrag = useCallback((clientX: number, clientY: number) => {
    const session = dragRef.current
    const instance = graphRef.current
    if (!session || !instance) return
    const zoom = instance.getZoom() || 1
    const screenX = clientX - session.startClientX
    const screenY = clientY - session.startClientY
    if (!session.active) {
      if (Math.hypot(screenX, screenY) < 3) return
      session.active = true
      suppressClick.current = true
      lastDragEnd.current = performance.now()
      paintNodeDrag(session.id, new Set(session.nodes.map((node) => node.id)))
      highlightDragEdges(session.id)
    }
    session.totalX = screenX / zoom
    session.totalY = screenY / zoom
    if (!session.frame) {
      session.frame = window.requestAnimationFrame(() => {
        const current = dragRef.current
        const graphInstance = graphRef.current
        if (!current || !graphInstance) return
        current.frame = 0
        const positions = Object.fromEntries(
          current.nodes.map((node) => [
            node.id,
            [
              node.start[0] + current.totalX * node.dragWeight,
              node.start[1] + current.totalY * node.dragWeight,
            ] as [number, number],
          ]),
        ) as Record<string, [number, number]>
        void graphInstance.translateElementTo(positions, false)
      })
    }
  }, [highlightDragEdges, paintNodeDrag])

  const endNodeDrag = useCallback(() => {
    const session = dragRef.current
    const instance = graphRef.current
    if (!session || !instance) return
    if (session.frame) {
      window.cancelAnimationFrame(session.frame)
      session.frame = 0
    }
    dragRef.current = null
    if (!session.active) {
      paintNodeDrag(null, new Set())
      return
    }
    lastDragEnd.current = performance.now()
    window.setTimeout(() => {
      suppressClick.current = false
    }, 500)
    const { nodes, totalX, totalY } = session
    const settle = (progress: number) => {
      const positions = Object.fromEntries(
        nodes.map((node) => {
          const weight = node.dragWeight + (node.releaseWeight - node.dragWeight) * progress
          return [
            node.id,
            [node.start[0] + totalX * weight, node.start[1] + totalY * weight] as [number, number],
          ]
        }),
      ) as Record<string, [number, number]>
      void instance.translateElementTo(positions, false)
    }
    const finish = () => {
      paintNodeDrag(null, new Set())
      highlightDragEdges(null)
      settleRef.current = null
    }
    if (
      window.matchMedia('(prefers-reduced-motion: reduce)').matches ||
      nodes.length === 0 ||
      Math.abs(totalX) + Math.abs(totalY) < 1
    ) {
      settle(1)
      finish()
      return
    }
    settle(0)
    const progress = { value: 0 }
    settleRef.current = animate(progress, {
      value: 1,
      duration: 680,
      ease: spring({ stiffness: 150, damping: 18 }),
      onUpdate: () => settle(progress.value),
      onComplete: finish,
    })
  }, [highlightDragEdges, paintNodeDrag])

  useEffect(() => {
    const container = frame.current
    if (!container || !hasNodes) {
      setReady(false)
      return
    }

    let disposed = false
    let created: Graph | null = null
    setReady(false)
    setError(null)

    // Defer creation by one task: React StrictMode mounts, cleans up and mounts
    // again in development, and a graph created synchronously would be
    // destroyed while its first render is still in flight.
    const timer = window.setTimeout(() => {
      if (disposed) return
      const current = elementsRef.current
      const graphInstance = new Graph({
        container,
        autoResize: true,
        background: 'transparent',
        padding: 52,
        zoomRange: [0.35, 2.4],
        animation: { duration: 280, easing: 'ease-out' },
        data: { nodes: current.nodes, edges: current.edges },
        node: {
          type: 'react',
          style: {
            size: [NODE_W, NODE_H],
            component: ((datum: NodeDatum) => (
              <WorldGraphNode
                datum={datum}
                tokens={tokens}
                onSelect={onSelect}
                onBeginDrag={beginNodeDrag}
                onMoveDrag={moveNodeDrag}
                onEndDrag={endNodeDrag}
              />
            )) as never,
          },
        },
        edge: {
          type: 'quadratic',
          style: {
            stroke: (datum: { data?: GraphEdgeData }) =>
              datum.data?.dragActive || datum.data?.active ? tokens.primary : tokens.borderStrong,
            lineWidth: (datum: { data?: GraphEdgeData }) =>
              datum.data?.dragActive ? 2.5 : datum.data?.active ? 2.2 : 1.1,
            opacity: (datum: { data?: GraphEdgeData }) =>
              datum.data?.dragActive ? 1 : datum.data?.dimmed ? 0.16 : datum.data?.active ? 1 : 0.55,
            endArrow: true,
            endArrowSize: 7,
            endArrowFill: (datum: { data?: GraphEdgeData }) =>
              datum.data?.dragActive || datum.data?.active ? tokens.primary : tokens.borderStrong,
            curveOffset: (datum: { data?: GraphEdgeData }) => {
              const index = datum.data?.pairIndex ?? 0
              const count = datum.data?.pairCount ?? 1
              return (index - (count - 1) / 2) * 24
            },
            curvePosition: 0.5,
            labelText: (datum: { data?: GraphEdgeData }) =>
              datum.data?.labelVisible ? datum.data.edge.label.replace(/_/g, ' ') : '',
            labelFill: tokens.text,
            labelFontFamily: WORLD_MONO,
            labelFontSize: 11,
            labelBackground: true,
            labelBackgroundFill: tokens.canvas,
            labelBackgroundRadius: 6,
            labelBackgroundOpacity: 0.95,
            labelPadding: [2, 6],
          } as never,
        },
        layout: {
          type: 'force',
          preventOverlap: true,
          nodeSize: [NODE_W, NODE_H],
          nodeSpacing: 22,
          linkDistance: 160,
          nodeStrength: -360,
          edgeStrength: 0.7,
          gravity: 30,
          maxIteration: 500,
          dimensions: 2,
        } as never,
        behaviors: ['drag-canvas', 'zoom-canvas'],
      })

      created = graphInstance
      graphRef.current = graphInstance

      const onNodeClick = (event: unknown) => {
        if (suppressClick.current) {
          suppressClick.current = false
          return
        }
        if (performance.now() - lastDragEnd.current < 300) return
        const target = (event as { target?: { id?: unknown } }).target
        const id = target?.id
        if (typeof id !== 'string') return
        onSelect(id === selectedRef.current ? null : id)
      }
      const onCanvasClick = () => onSelect(null)
      const fit = () => {
        if (disposed) return
        void graphInstance.fitView({ when: 'always' }, { duration: 320, easing: 'ease-out' })
      }

      graphInstance.on('node:click', onNodeClick)
      graphInstance.on('canvas:click', onCanvasClick)
      graphInstance.on('afterlayout', fit)
      graphInstance
        .render()
        .then(() => {
          if (!disposed) setReady(true)
        })
        .catch((reason: unknown) => {
          if (!disposed) setError(reason instanceof Error ? reason.message : 'The graph could not be drawn.')
        })
    }, 0)

    return () => {
      disposed = true
      window.clearTimeout(timer)
      settleRef.current?.cancel()
      settleRef.current = null
      if (dragRef.current?.frame) window.cancelAnimationFrame(dragRef.current.frame)
      dragRef.current = null
      created?.destroy()
      if (graphRef.current === created) graphRef.current = null
      setReady(false)
    }
  }, [graph, hasNodes, onSelect, tokens, beginNodeDrag, moveNodeDrag, endNodeDrag])

  useEffect(() => {
    const graphInstance = graphRef.current
    if (!graphInstance || !ready) return
    const current = elementsRef.current
    graphInstance.updateNodeData(current.nodes.map(({ id, data }) => ({ id, data })))
    graphInstance.updateEdgeData(current.edges.map(({ id, data }) => ({ id, data })))
    void graphInstance.draw()
  }, [elements, ready])

  // Opening the entity panel narrows the graph column; refit after the resize
  // so the selected mark cannot end up under the panel.
  useEffect(() => {
    const element = frame.current
    if (!element || !ready) return
    let timer: number | undefined
    const observer = new ResizeObserver(() => {
      window.clearTimeout(timer)
      timer = window.setTimeout(() => {
        const graphInstance = graphRef.current
        if (!graphInstance) return
        // autoResize only listens to the window; the entity panel changes this
        // container's width, so resize it explicitly before refitting.
        graphInstance.resize()
        // G6's fitView is a relative transform; reset first so repeated fits
        // cannot compound the zoom after the panel opens or the window resizes.
        void graphInstance.zoomTo(1, false).then(() =>
          graphInstance.fitView({ when: 'always' }, { duration: 220, easing: 'ease-out' }),
        )
      }, 140)
    })
    observer.observe(element)
    return () => {
      observer.disconnect()
      window.clearTimeout(timer)
    }
  }, [ready])


  const zoom = (factor: number) => {
    void graphRef.current?.zoomBy(factor, { duration: 180, easing: 'ease-out' })
  }
  const fit = () => {
    void graphRef.current?.fitView({ when: 'always' }, { duration: 280, easing: 'ease-out' })
  }

  return (
    <div className="flex min-w-0 flex-col gap-3">
      <div
        className="relative min-w-0 overflow-hidden rounded-2xl border"
        style={{
          backgroundColor: tokens.canvas,
          backgroundImage: `radial-gradient(circle, ${tokens.borderStrong}4d 0.8px, transparent 0.9px)`,
          backgroundSize: '22px 22px',
          backgroundPosition: '11px 11px',
          borderColor: tokens.border,
        }}
      >
        <div
          className="absolute right-2 top-2 z-10 flex flex-col overflow-hidden rounded-xl border"
          style={{ borderColor: tokens.border, background: tokens.surface }}
        >
          <IconButton label="Zoom in" size="lg" variant="ghost" onClick={() => zoom(1.25)}>
            <Plus aria-hidden />
          </IconButton>
          <IconButton label="Zoom out" size="lg" variant="ghost" onClick={() => zoom(1 / 1.25)}>
            <Minus aria-hidden />
          </IconButton>
          <IconButton label="Fit to screen" size="lg" variant="ghost" onClick={fit}>
            <Maximize2 aria-hidden />
          </IconButton>
        </div>

        {hasNodes ? (
          <div
            ref={frame}
            className="world-graph-frame h-[56vh] min-h-72 max-h-[560px] w-full"
            role="group"
            aria-label="World diagram"
          />
        ) : (
          <div className="flex min-h-72 items-center justify-center px-6 text-center">
            <p className="max-w-sm text-sm" style={{ color: tokens.muted }}>
              No relations yet. As the assistant learns how people, places and things connect, they will appear here.
            </p>
          </div>
        )}

        {error && (
          <p className="absolute inset-x-4 bottom-4 rounded-lg px-3 py-2 text-sm" style={{ background: tokens.surface, color: tokens.danger }}>
            {error}
          </p>
        )}
      </div>

      <IsolatedShelf
        nodes={elements.isolated}
        selectedId={selectedId}
        onSelect={onSelect}
        typeColor={typeColor}
        tokens={tokens}
      />
    </div>
  )
}

function WorldGraphNode({
  datum,
  tokens,
  onSelect,
  onBeginDrag,
  onMoveDrag,
  onEndDrag,
}: {
  datum: NodeDatum
  tokens: WorldGraphTokens
  onSelect: (id: string | null) => void
  onBeginDrag: (id: string, clientX: number, clientY: number) => void
  onMoveDrag: (clientX: number, clientY: number) => void
  onEndDrag: () => void
}) {
  const data = datum.data
  const [pressed, setPressed] = useState(false)
  if (!data) return null
  const { node, color, selected, dimmed, degree } = data
  return (
    <div
      role="button"
      tabIndex={0}
      data-node-id={node.id}
      data-pressed={pressed ? 'true' : 'false'}
      aria-pressed={selected}
      aria-label={`${node.label}, ${node.subtype ?? 'unknown type'}, ${degree} ${degree === 1 ? 'relation' : 'relations'}`}
      className={dimmed ? 'world-graph-node world-graph-node--dimmed' : 'world-graph-node'}
      style={
        {
          color: tokens.text,
          '--mark-color': color,
          '--mark-surface': tokens.surface,
          '--mark-border': tokens.border,
          '--mark-muted': tokens.muted,
        } as CSSProperties
      }
      onPointerDown={(event) => {
        if (event.pointerType !== 'mouse') setPressed(true)
        try {
          event.currentTarget.setPointerCapture(event.pointerId)
        } catch {
          // Synthetic or already-released pointers cannot be captured.
        }
        onBeginDrag(node.id, event.clientX, event.clientY)
      }}
      onPointerMove={(event) => onMoveDrag(event.clientX, event.clientY)}
      onPointerUp={(event) => {
        setPressed(false)
        onEndDrag()
        try {
          if (event.currentTarget.hasPointerCapture(event.pointerId)) {
            event.currentTarget.releasePointerCapture(event.pointerId)
          }
        } catch {
          // The pointer may already be gone.
        }
      }}
      onPointerCancel={() => {
        setPressed(false)
        onEndDrag()
      }}
      onPointerLeave={() => setPressed(false)}
      onKeyDown={(event) => {
        if (event.key === 'Enter' || event.key === ' ') {
          event.preventDefault()
          onSelect(selected ? null : node.id)
        }
      }}
    >
      <WorldMark type={node.subtype} color={color} tokens={tokens} degree={degree} selected={selected} />
      <span className="world-graph-label">{node.label}</span>
    </div>
  )
}

function IsolatedShelf({
  nodes,
  selectedId,
  onSelect,
  typeColor,
  tokens,
}: {
  nodes: WorldNode[]
  selectedId: string | null
  onSelect: (id: string | null) => void
  typeColor: (type?: string) => string
  tokens: WorldGraphTokens
}) {
  if (nodes.length === 0) return null
  return (
    <div className="rounded-2xl border p-3" style={{ background: tokens.surface, borderColor: tokens.border }}>
      <div className="mb-2 flex flex-wrap items-baseline justify-between gap-2">
        <span className="font-mono text-2xs uppercase tracking-[0.12em]" style={{ color: tokens.muted }}>
          Not yet related · {nodes.length}
        </span>
        <span className="text-2xs" style={{ color: tokens.muted }}>
          Select one to inspect it
        </span>
      </div>
      <div className="flex flex-wrap gap-2">
        {nodes.map((node) => {
          const color = typeColor(node.subtype)
          const active = node.id === selectedId
          return (
            <button
              key={node.id}
              type="button"
              aria-pressed={active}
              onClick={() => onSelect(active ? null : node.id)}
              className="inline-flex min-h-9 items-center gap-2 rounded-full border px-3 py-1.5 text-left transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-flat-primary"
              style={{
                borderColor: active ? color : tokens.border,
                background: active ? `${color}14` : tokens.canvas,
                color: tokens.text,
              }}
            >
              <WorldMark
                type={node.subtype}
                color={color}
                tokens={tokens}
                size={16}
                showIcon={false}
                showDegree={false}
                showOrbit={false}
              />
              <span className="max-w-[220px] truncate text-sm font-medium">{node.label}</span>
              <span className="font-mono text-2xs" style={{ color }}>
                {node.subtype ?? 'unknown'}
              </span>
            </button>
          )
        })}
      </div>
    </div>
  )
}

function buildElements(
  graph: SemanticWorldGraph,
  selectedId: string | null,
  typeColor: (type?: string) => string,
): {
  nodes: Array<{ id: string; style: { size: [number, number] }; data: GraphNodeData }>
  edges: Array<{ id: string; source: string; target: string; data: GraphEdgeData }>
  isolated: WorldNode[]
} {
  const degree = new Map<string, number>()
  for (const edge of graph.edges) {
    degree.set(edge.from, (degree.get(edge.from) ?? 0) + 1)
    degree.set(edge.to, (degree.get(edge.to) ?? 0) + 1)
  }
  const connected = graph.nodes.filter((node) => (degree.get(node.id) ?? 0) > 0)
  const isolated = graph.nodes.filter((node) => (degree.get(node.id) ?? 0) === 0)
  const connectedIds = new Set(connected.map((node) => node.id))
  const activeSelection = selectedId && connectedIds.has(selectedId) ? selectedId : null
  const near = activeSelection
    ? new Set<string>([
        activeSelection,
        ...graph.edges.flatMap((edge) =>
          edge.from === activeSelection ? [edge.to] : edge.to === activeSelection ? [edge.from] : [],
        ),
      ])
    : null

  const pairKey = (edge: WorldEdge) => (edge.from < edge.to ? `${edge.from}|${edge.to}` : `${edge.to}|${edge.from}`)
  const pairTotals = new Map<string, number>()
  const pairSeen = new Map<string, number>()
  for (const edge of graph.edges) {
    const key = pairKey(edge)
    pairTotals.set(key, (pairTotals.get(key) ?? 0) + 1)
  }
  // A hub can have a dozen incident routes; their labels would pile up. The
  // entity panel already lists every relation, so the graph keeps labels for
  // focused nodes whose neighbourhood is small enough to read.
  const focusRelations = activeSelection
    ? graph.edges.filter((edge) => edge.from === activeSelection || edge.to === activeSelection).length
    : 0
  const labelsFit = focusRelations <= 10

  const nodes = connected.map((node) => ({
    id: node.id,
    style: { size: [NODE_W, NODE_H] as [number, number] },
    data: {
      node,
      color: typeColor(node.subtype),
      selected: node.id === activeSelection,
      dimmed: near ? !near.has(node.id) : false,
      degree: degree.get(node.id) ?? 0,
    },
  }))

  const edges = graph.edges.flatMap((edge, index) => {
    if (!connectedIds.has(edge.from) || !connectedIds.has(edge.to)) return []
    const key = pairKey(edge)
    const pairIndex = pairSeen.get(key) ?? 0
    pairSeen.set(key, pairIndex + 1)
    const incident = !activeSelection || edge.from === activeSelection || edge.to === activeSelection
    return [
      {
        id: `edge:${index}`,
        source: edge.from,
        target: edge.to,
        data: {
          edge,
          active: Boolean(activeSelection) && incident,
          dragActive: false,
          labelVisible: Boolean(activeSelection) && incident && labelsFit,
          dimmed: Boolean(activeSelection) && !incident,
          pairIndex,
          pairCount: pairTotals.get(key) ?? 1,
        },
      },
    ]
  })

  return { nodes, edges, isolated }
}
