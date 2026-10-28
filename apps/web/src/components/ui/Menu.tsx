import type { ReactNode } from 'react'
import * as RadixMenu from '@radix-ui/react-dropdown-menu'
import { Link } from 'react-router-dom'
import { cn } from '../../lib/cn'

export type MenuItem =
  | {
      id: string
      label: ReactNode
      icon?: ReactNode
      onSelect?: () => void
      href?: string
      tone?: 'default' | 'danger'
      disabled?: boolean
      shortcut?: string
    }
  | { type: 'separator'; id?: string }
  | { type: 'label'; label: string; id?: string }

export type MenuProps = {
  trigger: ReactNode
  items: MenuItem[]
  side?: 'top' | 'right' | 'bottom' | 'left'
  align?: 'start' | 'center' | 'end'
  className?: string
}

const itemClass = (tone?: 'default' | 'danger', disabled?: boolean) =>
  cn(
    'flex cursor-pointer select-none items-center gap-2 rounded-sm px-2 py-1.5 text-base outline-none',
    '[&_svg]:size-4 [&_svg]:text-flat-muted-fg',
    tone === 'danger' ? 'text-flat-danger' : 'text-flat-foreground',
    'data-[highlighted]:bg-flat-muted',
    disabled && 'pointer-events-none opacity-50',
  )

export default function Menu({ trigger, items, side = 'bottom', align = 'end', className }: MenuProps) {
  return (
    <RadixMenu.Root>
      <RadixMenu.Trigger asChild>{trigger}</RadixMenu.Trigger>
      <RadixMenu.Portal>
        <RadixMenu.Content
          side={side}
          align={align}
          sideOffset={6}
          collisionPadding={12}
          className={cn(
            'z-50 min-w-44 rounded-md border border-flat-border bg-flat-surface-raised p-1 shadow-2',
            className,
          )}
        >
          {items.map((item, i) => {
            if ('type' in item && item.type === 'separator') {
              return <RadixMenu.Separator key={item.id ?? i} className="my-1 h-px bg-flat-border" />
            }
            if ('type' in item && item.type === 'label') {
              return (
                <RadixMenu.Label key={item.id ?? i} className="px-2 py-1 text-2xs text-flat-subtle-fg">
                  {item.label}
                </RadixMenu.Label>
              )
            }
            const row = (
              <span className="flex flex-1 items-center gap-2">
                {item.icon}
                <span className="flex-1">{item.label}</span>
                {item.shortcut && (
                  <span className="font-mono text-2xs text-flat-subtle-fg">{item.shortcut}</span>
                )}
              </span>
            )
            return (
              <RadixMenu.Item
                key={item.id}
                disabled={item.disabled}
                onSelect={item.onSelect}
                className={itemClass(item.tone, item.disabled)}
                asChild={!!item.href}
              >
                {item.href ? <Link to={item.href}>{row}</Link> : row}
              </RadixMenu.Item>
            )
          })}
        </RadixMenu.Content>
      </RadixMenu.Portal>
    </RadixMenu.Root>
  )
}
