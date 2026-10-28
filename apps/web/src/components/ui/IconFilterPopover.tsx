import {
  useEffect,
  useId,
  useRef,
  useState,
  type ReactNode,
} from 'react'
import { cn } from '../../lib/cn'

type Props = {
  icon: ReactNode
  title: string
  active?: boolean
  align?: 'left' | 'right'
  className?: string
  children: ReactNode
}

export default function IconFilterPopover({
  icon,
  title,
  active = false,
  align = 'right',
  className,
  children,
}: Props) {
  const [open, setOpen] = useState(false)
  const rootRef = useRef<HTMLDivElement>(null)
  const panelId = useId()

  useEffect(() => {
    if (!open) {
      return
    }

    const onPointerDown = (event: MouseEvent) => {
      if (!rootRef.current?.contains(event.target as Node)) {
        setOpen(false)
      }
    }

    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        setOpen(false)
      }
    }

    document.addEventListener('mousedown', onPointerDown)
    document.addEventListener('keydown', onKeyDown)
    return () => {
      document.removeEventListener('mousedown', onPointerDown)
      document.removeEventListener('keydown', onKeyDown)
    }
  }, [open])

  return (
    <div ref={rootRef} className={cn('icon-popup-menu', className)}>
      <button
        type="button"
        className={cn('icon-popup-trigger', active && 'icon-popup-trigger-active')}
        aria-label={title}
        aria-haspopup="dialog"
        aria-expanded={open}
        aria-controls={panelId}
        onClick={() => setOpen((current) => !current)}
      >
        {icon}
      </button>

      {open && (
        <div
          id={panelId}
          className={cn(
            'icon-filter-panel',
            align === 'right' && 'icon-filter-panel-right',
          )}
          role="dialog"
          aria-label={title}
        >
          <p className="icon-popup-title">{title}</p>
          <div className="icon-filter-panel-body">{children}</div>
        </div>
      )}
    </div>
  )
}
