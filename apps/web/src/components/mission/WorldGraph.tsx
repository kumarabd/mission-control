import { lazy, Suspense, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { MessageSquare, X } from 'lucide-react'
import { cn } from '../../lib/cn'
import type { SemanticWorldGraph, WorldEdge, WorldNode } from '../../lib/types'
import { useTheme } from '../../theme/theme-context'
import { IconButton, Segmented } from '../ui'
import {
  WORLD_GRAPH_TOKENS,
  WORLD_GRAPH_TYPE_KEYS,
  type WorldGraphTokens,
} from './worldGraphTokens'
import { WorldMark } from './worldGraphMarks'

const WorldGraphG6 = lazy(() => import('./WorldGraphG6'))

/**
 * The World lens: the person's entities, what is known about each, and how they relate, drawn as a diagram
 * with a list alternative. Entity types and attribute names are free text the assistant chose, so they are
 * displayed as they come and never switched on.
 */

/**
 * One colour per type, assigned in alphabetical order so two types on screen never share one (up to six; after
 * that colours repeat). No type reads neutral.
 */
function makeTypeColor(types: string[], tokens: WorldGraphTokens): (type?: string) => string {
  const order = [...types].sort()
  return (type) => {
    if (!type) return tokens.muted
    const i = order.indexOf(type)
    return i < 0 ? tokens.muted : tokens[WORLD_GRAPH_TYPE_KEYS[i % WORLD_GRAPH_TYPE_KEYS.length]]
  }
}

const entityId = (node: WorldNode) => (node.id.startsWith('entity:') ? node.id.slice('entity:'.length) : node.id)
const phrase = (edge: WorldEdge) => edge.label.replace(/_/g, ' ')
const UNTYPED = '__untyped__'
const nodeTypeKey = (node: WorldNode) => node.subtype ?? UNTYPED

type Mode = 'diagram' | 'list'

export default function WorldGraph({
  graph,
  onDiscuss,
}: {
  graph: SemanticWorldGraph
  onDiscuss: (entity?: string) => void
}) {
  const { theme } = useTheme()
  const tokens = WORLD_GRAPH_TOKENS[theme]
  const [mode, setMode] = useState<Mode>('diagram')
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [hiddenTypes, setHiddenTypes] = useState<Set<string>>(() => new Set())
  const types = useMemo(() => Array.from(new Set(graph.nodes.flatMap((n) => (n.subtype ? [n.subtype] : [])))).sort(), [graph])
  const typeColor = useMemo(() => makeTypeColor(types, tokens), [types, tokens])
  const typeCounts = useMemo(() => {
    const counts = new Map<string, number>()
    for (const node of graph.nodes) counts.set(nodeTypeKey(node), (counts.get(nodeTypeKey(node)) ?? 0) + 1)
    return counts
  }, [graph])
  const legendKeys = useMemo(
    () => [...types, ...(typeCounts.has(UNTYPED) ? [UNTYPED] : [])],
    [types, typeCounts],
  )
  const filteredGraph = useMemo(() => {
    if (hiddenTypes.size === 0) return graph
    const visible = graph.nodes.filter((node) => !hiddenTypes.has(nodeTypeKey(node)))
    const ids = new Set(visible.map((node) => node.id))
    return { ...graph, nodes: visible, edges: graph.edges.filter((edge) => ids.has(edge.from) && ids.has(edge.to)) }
  }, [graph, hiddenTypes])
  const nodes = useMemo(() => new Map(filteredGraph.nodes.map((n) => [n.id, n])), [filteredGraph])
  const selected = selectedId ? (nodes.get(selectedId) ?? null) : null
  const filteredOut = graph.nodes.length > 0 && filteredGraph.nodes.length === 0

  const toggleType = (key: string) => {
    const next = new Set(hiddenTypes)
    if (next.has(key)) next.delete(key)
    else next.add(key)
    setHiddenTypes(next)
    if (selectedId) {
      const selectedNode = graph.nodes.find((node) => node.id === selectedId)
      if (selectedNode && next.has(nodeTypeKey(selectedNode))) setSelectedId(null)
    }
  }
  const resetTypes = () => {
    if (selectedId) {
      const selectedNode = graph.nodes.find((node) => node.id === selectedId)
      if (selectedNode && hiddenTypes.has(nodeTypeKey(selectedNode))) setSelectedId(null)
    }
    setHiddenTypes(new Set())
  }

  return (
    <div className="flex flex-col gap-3">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="flex min-w-0 flex-1 flex-wrap items-center gap-1.5" role="group" aria-label="Entity types. Toggle one to filter the world.">
          {legendKeys.map((key) => {
            const hidden = hiddenTypes.has(key)
            const label = key === UNTYPED ? 'no type' : key
            const color = key === UNTYPED ? tokens.muted : typeColor(key)
            return (
              <button
                key={key}
                type="button"
                aria-pressed={!hidden}
                title={`${hidden ? 'Show' : 'Hide'} ${label}`}
                onClick={() => toggleType(key)}
                className="flex items-center gap-1.5 rounded-full border px-2 py-1 font-mono text-2xs transition-opacity focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-flat-primary"
                style={{
                  borderColor: hidden ? tokens.border : `${color}66`,
                  background: hidden ? 'transparent' : `${color}10`,
                  color: hidden ? tokens.muted : tokens.text,
                  opacity: hidden ? 0.55 : 1,
                }}
              >
                <WorldMark
                  type={key === UNTYPED ? undefined : key}
                  color={color}
                  tokens={tokens}
                  size={16}
                  showIcon={false}
                  showDegree={false}
                  showOrbit={false}
                />
                {label}
                <span style={{ color: hidden ? tokens.muted : color }}>{typeCounts.get(key) ?? 0}</span>
              </button>
            )
          })}
          {hiddenTypes.size > 0 && (
            <button
              type="button"
              onClick={resetTypes}
              className="rounded-full border px-2 py-1 font-mono text-2xs transition-colors hover:bg-flat-muted/60 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-flat-primary"
              style={{ borderColor: tokens.borderStrong, color: tokens.primary }}
            >
              Show all
            </button>
          )}
          <span className="ml-1 font-mono text-2xs" style={{ color: tokens.muted }}>
            {hiddenTypes.size === 0
              ? `${graph.nodes.length} ${graph.nodes.length === 1 ? 'entity' : 'entities'} · ${graph.edges.length} ${graph.edges.length === 1 ? 'relation' : 'relations'}`
              : `${filteredGraph.nodes.length} of ${graph.nodes.length} entities · ${filteredGraph.edges.length} of ${graph.edges.length} relations`}
          </span>
        </div>
        <Segmented
          size="sm"
          value={mode}
          onValueChange={setMode}
          options={[
            { value: 'diagram', label: 'Diagram' },
            { value: 'list', label: 'List' },
          ]}
        />
      </div>

      {filteredOut ? (
        <div className="flex min-h-72 flex-col items-center justify-center gap-3 rounded-2xl border border-flat-border bg-flat-surface px-6 text-center">
          <p className="max-w-sm text-sm text-flat-muted-fg">No entities match these filters.</p>
          <button
            type="button"
            onClick={resetTypes}
            className="rounded-full border px-3 py-1.5 text-sm font-medium text-flat-primary transition-colors hover:bg-flat-muted/60 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-flat-primary"
            style={{ borderColor: tokens.borderStrong }}
          >
            Show all entities
          </button>
        </div>
      ) : (
        <div className={cn('grid gap-3', selected && 'lg:grid-cols-[minmax(0,1fr)_320px]')}>
          {mode === 'diagram' ? (
            <Suspense fallback={<GraphSkeleton tokens={tokens} />}>
              <WorldGraphG6
                graph={filteredGraph}
                selectedId={selectedId}
                onSelect={setSelectedId}
                typeColor={typeColor}
                tokens={tokens}
              />
            </Suspense>
          ) : (
            <WorldList
              graph={filteredGraph}
              selectedId={selectedId}
              onSelect={setSelectedId}
              typeColor={typeColor}
              tokens={tokens}
            />
          )}
          {selected ? (
            <EntityPanel
              node={selected}
              graph={filteredGraph}
              nodes={nodes}
              typeColor={typeColor}
              tokens={tokens}
              onSelect={setSelectedId}
              onClose={() => setSelectedId(null)}
              onDiscuss={() => onDiscuss(selected.label)}
            />
          ) : null}
        </div>
      )}

      {graph.truncated && (
        <p className="text-2xs text-flat-muted-fg">
          Showing the {graph.nodes.length} best-connected. Others appear as they gain relations.
        </p>
      )}
    </div>
  )
}

function GraphSkeleton({ tokens }: { tokens: WorldGraphTokens }) {
  return (
    <div
      className="h-[56vh] min-h-72 max-h-[560px] animate-pulse rounded-2xl border"
      style={{
        backgroundColor: tokens.canvas,
        backgroundImage: `radial-gradient(circle, ${tokens.borderStrong}4d 0.8px, transparent 0.9px)`,
        backgroundSize: '22px 22px',
        backgroundPosition: '11px 11px',
        borderColor: tokens.border,
      }}
      aria-label="Loading the world diagram"
    />
  )
}

function WorldList({
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
  const groups = useMemo(() => {
    const by = new Map<string, WorldNode[]>()
    for (const node of graph.nodes) by.set(node.subtype ?? 'Other', [...(by.get(node.subtype ?? 'Other') ?? []), node])
    return Array.from(by.entries()).sort(([a], [b]) => a.localeCompare(b))
  }, [graph])
  const count = (id: string) => graph.edges.filter((e) => e.from === id || e.to === id).length
  return (
    <div className="min-w-0 overflow-hidden rounded-2xl border border-flat-border bg-flat-surface">
      {groups.map(([type, list]) => (
        <section key={type}>
          <h3 className="flex items-center gap-1.5 border-b border-flat-border bg-flat-muted/40 px-4 py-2 font-mono text-2xs uppercase tracking-[0.12em] text-flat-muted-fg">
            <WorldMark
              type={type === 'Other' ? undefined : type}
              color={typeColor(type === 'Other' ? undefined : type)}
              tokens={tokens}
              size={14}
              showIcon={false}
              showDegree={false}
              showOrbit={false}
            />
            {type}
          </h3>
          {list.map((node) => {
            const attrs = Object.entries(node.attributes ?? {}).sort(([a], [b]) => a.localeCompare(b))
            const n = count(node.id)
            return (
              <button
                key={node.id}
                type="button"
                aria-pressed={node.id === selectedId}
                onClick={() => onSelect(node.id === selectedId ? null : node.id)}
                className={cn(
                  'block min-h-11 w-full border-b border-flat-border px-4 py-3 text-left last:border-b-0 hover:bg-flat-muted/50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-flat-primary',
                  node.id === selectedId && 'bg-flat-tint-soft',
                )}
              >
                <span className="block text-native-callout font-medium text-flat-foreground">{node.label}</span>
                {attrs.length > 0 && (
                  <span className="mt-0.5 line-clamp-2 block text-sm text-flat-muted-fg">
                    {attrs.slice(0, 3).map(([k, v]) => `${k}: ${v}`).join(' · ')}
                  </span>
                )}
                {n > 0 && <span className="mt-0.5 block font-mono text-2xs text-flat-muted-fg">{n} {n === 1 ? 'relation' : 'relations'}</span>}
              </button>
            )
          })}
        </section>
      ))}
    </div>
  )
}

function EntityPanel({
  node,
  graph,
  nodes,
  typeColor,
  tokens,
  onSelect,
  onClose,
  onDiscuss,
}: {
  node: WorldNode
  graph: SemanticWorldGraph
  nodes: Map<string, WorldNode>
  typeColor: (type?: string) => string
  tokens: WorldGraphTokens
  onSelect: (id: string) => void
  onClose: () => void
  onDiscuss: () => void
}) {
  const attributes = Object.entries(node.attributes ?? {}).sort(([a], [b]) => a.localeCompare(b))
  const mine = graph.edges.filter((e) => e.from === node.id || e.to === node.id)
  return (
    <aside aria-label={`${node.label}`} className="min-w-0 rounded-2xl border border-flat-border bg-flat-surface p-4">
      <div className="flex items-start justify-between gap-2">
        <div className="flex min-w-0 items-start gap-2.5">
          <WorldMark
            type={node.subtype}
            color={typeColor(node.subtype)}
            tokens={tokens}
            size={30}
            showDegree={false}
            showOrbit={false}
          />
          <div className="min-w-0">
            <h2 className="truncate text-native-callout font-semibold text-flat-foreground">{node.label}</h2>
            <p className="font-mono text-2xs" style={{ color: typeColor(node.subtype) }}>
              {node.subtype ?? 'No type yet'}
            </p>
          </div>
        </div>
        <IconButton label="Close" variant="ghost" onClick={onClose}>
          <X aria-hidden />
        </IconButton>
      </div>

      {attributes.length ? (
        <dl className="mt-3 grid grid-cols-[auto_minmax(0,1fr)] gap-x-4 gap-y-1.5 text-sm">
          {attributes.map(([key, value]) => (
            <div key={key} className="contents">
              <dt className="font-mono text-2xs text-flat-muted-fg">{key}</dt>
              <dd className="text-flat-foreground">{value}</dd>
            </div>
          ))}
        </dl>
      ) : (
        <p className="mt-3 text-sm text-flat-muted-fg">Nothing is known about {node.label} yet beyond its name.</p>
      )}

      {mine.length > 0 && (
        <div className="mt-4">
          <p className="mb-1 font-mono text-2xs uppercase tracking-[0.12em] text-flat-muted-fg">relations</p>
          <ul>
            {mine.map((edge) => {
              const outgoing = edge.from === node.id
              const otherId = outgoing ? edge.to : edge.from
              const other = nodes.get(otherId)
              if (!other) return null
              return (
                <li key={`${edge.from}>${edge.label}>${edge.to}`}>
                  <button
                    type="button"
                    onClick={() => onSelect(otherId)}
                    aria-label={outgoing ? `${node.label} ${phrase(edge)} ${other.label}` : `${other.label} ${phrase(edge)} ${node.label}`}
                    className="flex min-h-11 w-full items-center gap-2 rounded-md px-1 text-left hover:bg-flat-muted/50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-flat-primary"
                  >
                    <span className="font-mono text-2xs text-flat-muted-fg">{outgoing ? `${phrase(edge)} →` : `← ${phrase(edge)}`}</span>
                    <span className="min-w-0 truncate text-sm font-medium text-flat-foreground">{other.label}</span>
                    {edge.source_count > 0 && (
                      <span className="ml-auto shrink-0 font-mono text-2xs text-flat-muted-fg">
                        {edge.source_count} {edge.source_count === 1 ? 'fact' : 'facts'}
                      </span>
                    )}
                  </button>
                </li>
              )
            })}
          </ul>
        </div>
      )}

      <div className="mt-4 flex flex-wrap items-center gap-x-5 gap-y-1 text-sm font-medium">
        <Link
          to={`/memory/entity/${encodeURIComponent(entityId(node))}`}
          className="inline-flex min-h-11 items-center text-flat-primary hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-flat-primary"
        >
          What I remember
        </Link>
        <button
          type="button"
          onClick={onDiscuss}
          className="inline-flex min-h-11 items-center gap-1.5 text-flat-primary hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-flat-primary"
        >
          <MessageSquare className="size-4" aria-hidden /> Discuss
        </button>
      </div>
    </aside>
  )
}
