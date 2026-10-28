import type { CSSProperties } from 'react'
import {
  Building2,
  CalendarDays,
  CircleDot,
  Layers,
  MapPin,
  Sparkles,
  UserRound,
  UsersRound,
  Wrench,
} from 'lucide-react'
import type { WorldGraphTokens } from './worldGraphTokens'
import {
  kindForType,
  markSize,
  orbitSize,
  shapeForType,
  type WorldKind,
  type WorldShape,
} from './worldGraphShapes'
import './worldGraph.css'

function MarkIcon({ kind, size, color }: { kind: WorldKind; size: number; color: string }) {
  const props = { size, strokeWidth: 1.7, color, 'aria-hidden': true } as const
  switch (kind) {
    case 'organization':
      return <Building2 {...props} />
    case 'team':
      return <UsersRound {...props} />
    case 'place':
      return <MapPin {...props} />
    case 'project':
      return <Layers {...props} />
    case 'tool':
      return <Wrench {...props} />
    case 'event':
      return <CalendarDays {...props} />
    case 'person':
      return <UserRound {...props} />
    case 'concept':
      return <Sparkles {...props} />
    case 'other':
      return <CircleDot {...props} />
  }
}

function shapeDrawing(shape: WorldShape, color: string, selected: boolean) {
  const props = {
    fill: color,
    fillOpacity: selected ? 0.2 : 0.1,
    stroke: color,
    strokeOpacity: selected ? 1 : 0.72,
    strokeWidth: selected ? 2 : 1.5,
    strokeLinejoin: 'round' as const,
  }
  switch (shape) {
    case 'diamond':
      return <rect x="11" y="11" width="26" height="26" rx="5" transform="rotate(45 24 24)" {...props} />
    case 'hexagon':
      return <polygon points="24,3 42,13.5 42,34.5 24,45 6,34.5 6,13.5" {...props} />
    case 'square':
      return <rect x="5" y="5" width="38" height="38" rx="9" {...props} />
    case 'octagon':
      return <polygon points="16,4 32,4 44,16 44,32 32,44 16,44 4,32 4,16" {...props} />
    case 'pentagon':
      return <polygon points="24,3 45,18 37,42 11,42 3,18" {...props} />
    case 'dashed':
      return <circle cx="24" cy="24" r="21" {...props} strokeDasharray="4 4" />
    case 'circle':
    default:
      return <circle cx="24" cy="24" r="21" {...props} />
  }
}

export function WorldMark({
  type,
  color,
  tokens,
  degree = 0,
  selected = false,
  size,
  showIcon = true,
  showDegree = true,
  showOrbit = true,
}: {
  type?: string
  color: string
  tokens: WorldGraphTokens
  degree?: number
  selected?: boolean
  size?: number
  showIcon?: boolean
  showDegree?: boolean
  showOrbit?: boolean
}) {
  const shape = shapeForType(type)
  const kind = kindForType(type)
  const glyph = size ?? markSize(degree)
  const orbit = Math.max(glyph + 10, orbitSize(degree))
  const box = showOrbit ? Math.max(glyph, orbit) + 4 : glyph
  const iconSize = Math.max(13, Math.round(glyph * (shape === 'diamond' ? 0.31 : 0.36)))
  const showsOrbit = showOrbit && (selected || degree >= 4)

  return (
    <span
      aria-hidden
      className="world-mark"
      style={
        {
          width: box,
          height: box,
          '--mark-color': color,
          '--mark-surface': tokens.surface,
          '--mark-border': tokens.border,
          '--mark-muted': tokens.muted,
        } as CSSProperties
      }
    >
      {showsOrbit && (
        <span
          className={selected ? 'world-mark-orbit world-mark-orbit--live' : 'world-mark-orbit'}
          style={{
            width: orbit,
            height: orbit,
            borderColor: selected ? color : `${color}66`,
          }}
        >
          {selected && (
            <span className="world-mark-satellite" style={{ background: color, boxShadow: `0 0 0 3px ${color}22` }} />
          )}
        </span>
      )}
      {selected && (
        <span className="world-mark-bloom" style={{ width: orbit, height: orbit, borderColor: color }} />
      )}
      <span className="world-mark-glyph" style={{ width: glyph, height: glyph }}>
        <svg width={glyph} height={glyph} viewBox="0 0 48 48" aria-hidden>
          {shapeDrawing(shape, color, selected)}
        </svg>
        {showIcon && (
          <span className="world-mark-icon">
            <MarkIcon kind={kind} size={iconSize} color={color} />
          </span>
        )}
        {showDegree && degree > 0 && <span className="world-mark-degree">{degree}</span>}
      </span>
    </span>
  )
}
