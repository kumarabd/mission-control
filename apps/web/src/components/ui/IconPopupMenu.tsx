import {
  useEffect,
  useId,
  useRef,
  useState,
  type ReactNode,
} from 'react'
import { cn } from '../../lib/cn'

export type PopupOption = {
  value: string
  label: string
}

type Props = {
  icon: ReactNode
  title: string
  value: string
  options: PopupOption[]
  onChange: (value: string) => void
  active?: boolean
  className?: string
}

export default function IconPopupMenu({
  icon,
  title,
  value,
  options,
  onChange,
  active = false,
  className,
}: Props) {
  const [open, setOpen] = useState(false)
  const rootRef = useRef<HTMLDivElement>(null)
  const listId = useId()

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

  const select = (next: string) => {
    onChange(next)
    setOpen(false)
  }

  return (
    <div ref={rootRef} className={cn('icon-popup-menu', className)}>
      <button
        type="button"
        className={cn('icon-popup-trigger', active && 'icon-popup-trigger-active')}
        aria-label={title}
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-controls={listId}
        onClick={() => setOpen((current) => !current)}
      >
        {icon}
      </button>

      {open && (
        <div className="icon-popup-panel" role="presentation">
          <p className="icon-popup-title">{title}</p>
          <ul id={listId} className="icon-popup-list" role="listbox" aria-label={title}>
            {options.map((option) => {
              const selected = option.value === value
              return (
                <li key={option.value || '__all__'} role="presentation">
                  <button
                    type="button"
                    role="option"
                    aria-selected={selected}
                    className={cn('icon-popup-option', selected && 'icon-popup-option-active')}
                    onClick={() => select(option.value)}
                  >
                    <span className="icon-popup-option-label">{option.label}</span>
                    {selected && <span className="icon-popup-check" aria-hidden="true">✓</span>}
                  </button>
                </li>
              )
            })}
          </ul>
        </div>
      )}
    </div>
  )
}

export function FilterIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <polygon points="22 3 2 3 10 12.46 10 19 14 21 14 12.46 22 3" />
    </svg>
  )
}

export function SortIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d="M11 5h10" />
      <path d="M11 9h7" />
      <path d="M11 13h4" />
      <path d="m3 17 3 3 3-3" />
      <path d="M6 18V4" />
    </svg>
  )
}
