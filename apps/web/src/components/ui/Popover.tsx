import type { ReactNode } from 'react'
import { useState } from 'react'
import * as RadixPopover from '@radix-ui/react-popover'
import { cn } from '../../lib/cn'

type Side = 'top' | 'right' | 'bottom' | 'left'
type Align = 'start' | 'center' | 'end'

export type PopoverProps = {
  trigger: ReactNode
  children: ReactNode | ((close: () => void) => ReactNode)
  open?: boolean
  onOpenChange?: (open: boolean) => void
  defaultOpen?: boolean
  side?: Side
  align?: Align
  sideOffset?: number
  width?: number | 'trigger'
  className?: string
  asChild?: boolean
}

export default function Popover({
  trigger,
  children,
  open: openProp,
  onOpenChange,
  defaultOpen,
  side = 'bottom',
  align = 'start',
  sideOffset = 6,
  width,
  className,
  asChild = true,
}: PopoverProps) {
  const [uncontrolled, setUncontrolled] = useState(defaultOpen ?? false)
  const controlled = openProp !== undefined
  const open = controlled ? openProp : uncontrolled
  const setOpen = (v: boolean) => {
    if (!controlled) setUncontrolled(v)
    onOpenChange?.(v)
  }

  return (
    <RadixPopover.Root open={open} onOpenChange={setOpen}>
      <RadixPopover.Trigger asChild={asChild}>{trigger}</RadixPopover.Trigger>
      <RadixPopover.Portal>
        <RadixPopover.Content
          side={side}
          align={align}
          sideOffset={sideOffset}
          collisionPadding={12}
          style={
            width === 'trigger'
              ? { width: 'var(--radix-popover-trigger-width)' }
              : width
                ? { width }
                : undefined
          }
          className={cn(
            'z-50 max-h-[min(24rem,var(--radix-popover-content-available-height))] overflow-auto rounded-md border border-flat-border bg-flat-surface-raised p-1 text-base text-flat-foreground shadow-2',
            className,
          )}
        >
          {typeof children === 'function'
            ? (children as (c: () => void) => ReactNode)(() => setOpen(false))
            : children}
        </RadixPopover.Content>
      </RadixPopover.Portal>
    </RadixPopover.Root>
  )
}
