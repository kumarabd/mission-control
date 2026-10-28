import {
  DndContext,
  KeyboardSensor,
  PointerSensor,
  closestCenter,
  useSensor,
  useSensors,
  type DragEndEvent,
} from '@dnd-kit/core'
import { SortableContext, sortableKeyboardCoordinates, useSortable, verticalListSortingStrategy } from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'
import { ArrowUpDown, GripVertical, Plus, X } from 'lucide-react'
import { Button } from '../../components/ui'
import { cn } from '../../lib/cn'
import { MAX_ROUTE_STOPS, routeEndPlace, routeStartPlace, useRouteStore, type RouteStopRow } from '../stores/routeStore'
import { PlaceInput } from './PlaceInput'

const letter = (i: number) => String.fromCharCode(65 + i)

const iconBtn =
  'flex size-9 shrink-0 items-center justify-center rounded-sm border border-flat-border text-flat-muted-fg transition-colors hover:border-flat-border-strong hover:text-flat-foreground disabled:opacity-40'

function StopRow({ row, index, shown, total, canPlan, onPlan, canSwap }: { row: RouteStopRow; index: number; shown: number; total: number; canPlan: boolean; onPlan: () => void; canSwap: boolean }) {
  const setStopPlaceAt = useRouteStore((s) => s.setStopPlaceAt)
  const removeStopAt = useRouteStore((s) => s.removeStopAt)
  const swap = useRouteStore((s) => s.swapRouteEndpoints)
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({ id: row.id })

  const first = index === 0
  const last = index === total - 1
  const removable = !first && !last
  const placeholder = first ? 'Starting point' : last ? 'Destination' : 'Add a stop'

  return (
    <div
      ref={setNodeRef}
      style={{ transform: CSS.Transform.toString(transform), transition }}
      className={cn('relative flex items-start gap-1.5', isDragging && 'z-10 opacity-80')}
    >
      <button
        type="button"
        aria-label={`Drag to reorder stop ${letter(shown)}`}
        className="mt-1.5 flex size-6 shrink-0 cursor-grab touch-none items-center justify-center rounded-sm text-flat-subtle-fg hover:text-flat-foreground active:cursor-grabbing"
        {...attributes}
        {...listeners}
      >
        <GripVertical className="size-4" />
      </button>
      <span
        aria-hidden
        className={cn(
          'relative z-[1] mt-2 flex size-5 shrink-0 items-center justify-center border-2 border-flat-surface text-2xs font-semibold',
          first && 'rounded-full bg-flat-foreground text-flat-background',
          last && 'rounded-[4px] bg-flat-foreground text-flat-background',
          removable && 'rounded-full bg-flat-warning text-flat-background',
        )}
      >
        {letter(shown)}
      </span>
      <PlaceInput
        label={`Stop ${letter(shown)}`}
        placeholder={placeholder}
        value={row.place}
        onChange={(p) => setStopPlaceAt(index, p)}
        onEnter={() => canPlan && onPlan()}
        onEscape={() => (last ? setStopPlaceAt(index, null) : removable && removeStopAt(index))}
        showMyLocationButton={first}
        trailing={
          last ? (
            <button type="button" onClick={swap} disabled={!canSwap} title="Reverse the route" aria-label="Reverse the route" className={iconBtn}>
              <ArrowUpDown className="size-4" />
            </button>
          ) : removable ? (
            <button type="button" onClick={() => removeStopAt(index)} title="Remove stop" aria-label="Remove stop" className={cn(iconBtn, 'hover:text-flat-danger')}>
              <X className="size-4" />
            </button>
          ) : undefined
        }
      />
    </div>
  )
}

export function StopList({ canPlan, onPlan }: { canPlan: boolean; onPlan: () => void }) {
  const routeStops = useRouteStore((s) => s.routeStops)
  const canSwap = useRouteStore((s) => Boolean(routeStartPlace(s.routeStops) && routeEndPlace(s.routeStops)))
  const addStop = useRouteStore((s) => s.addStopBeforeDestination)
  const reorder = useRouteStore((s) => s.reorderStopsByIndex)
  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 8 } }),
    useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates }),
  )

  const onDragEnd = ({ active, over }: DragEndEvent) => {
    if (!over || active.id === over.id) return
    const from = routeStops.findIndex((r) => r.id === active.id)
    const to = routeStops.findIndex((r) => r.id === over.id)
    if (from !== -1 && to !== -1) reorder(from, to)
  }

  return (
    <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={onDragEnd}>
      <SortableContext items={routeStops.filter((r) => !r.fromPlan).map((r) => r.id)} strategy={verticalListSortingStrategy}>
        <div className="relative space-y-2">
          {/* The spine the stops hang on; the results below continue it. */}
          <span aria-hidden className="absolute bottom-4 left-[2.1rem] top-4 w-px bg-flat-border-strong" />
          {routeStops
            .map((row, i) => ({ row, i }))
            .filter(({ row }) => !row.fromPlan)
            .map(({ row, i }, shown) => (
              <StopRow key={row.id} row={row} index={i} shown={shown} total={routeStops.length} canPlan={canPlan} onPlan={onPlan} canSwap={canSwap} />
            ))}
        </div>
      </SortableContext>
      <Button variant="ghost" size="sm" className="mt-2" iconLeft={<Plus className="size-4" />} onClick={addStop} disabled={routeStops.length >= MAX_ROUTE_STOPS}>
        Add a stop
      </Button>
    </DndContext>
  )
}
