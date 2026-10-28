import {
  Children,
  isValidElement,
  useEffect,
  useId,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react'
import { cn } from '../../lib/cn'

export type SelectOption = {
  value: string
  label: string
}

type BaseProps = {
  className?: string
  disabled?: boolean
  children?: ReactNode
  options?: SelectOption[]
  placeholder?: string
  /** show a "Clear" affordance for single-select */
  clearable?: boolean
  size?: 'sm' | 'md'
}

type SingleSelectProps = BaseProps & {
  multiple?: false
  value?: string | null
  onChange?: (event: { target: { value: string } }) => void
  onValueChange?: (value: string | null) => void
}

type MultiSelectProps = BaseProps & {
  multiple: true
  value?: string[]
  onChange?: (event: { target: { value: string[] } }) => void
  onValueChange?: (value: string[]) => void
}

type Props = SingleSelectProps | MultiSelectProps

function ChevronDown({ className }: { className?: string }) {
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
      <path d="m6 9 6 6 6-6" />
    </svg>
  )
}

function optionsFromChildren(children: ReactNode): SelectOption[] {
  const options: SelectOption[] = []
  Children.forEach(children, (child) => {
    if (!isValidElement(child) || child.type !== 'option') {
      return
    }
    const props = child.props as { value?: string; children?: ReactNode }
    const value = String(props.value ?? '')
    const label = String(props.children ?? props.value ?? '')
    options.push({ value, label })
  })
  return options
}

function summarizeSelection(
  selectedValues: string[],
  options: SelectOption[],
  placeholder: string,
): string {
  if (selectedValues.length === 0) {
    return placeholder
  }
  if (selectedValues.length === 1) {
    const match = options.find((option) => option.value === selectedValues[0])
    return match?.label ?? selectedValues[0]
  }
  if (selectedValues.length === 2) {
    const labels = selectedValues.map(
      (value) => options.find((option) => option.value === value)?.label ?? value,
    )
    return labels.join(', ')
  }
  return `${selectedValues.length} selected`
}

export default function Select(props: Props) {
  const {
    className,
    disabled,
    children,
    options: optionsProp,
    placeholder = 'Select…',
  } = props

  const multiple = props.multiple === true
  const [open, setOpen] = useState(false)
  const rootRef = useRef<HTMLDivElement>(null)
  const listId = useId()

  const options = useMemo(() => {
    const raw = optionsProp ?? optionsFromChildren(children)
    if (multiple) {
      return raw.filter((option) => option.value !== '')
    }
    return raw
  }, [optionsProp, children, multiple])

  const selectedValues = useMemo(() => {
    if (multiple) {
      return props.value ?? []
    }
    const single = String(props.value ?? '')
    return single ? [single] : []
  }, [multiple, props.value])

  const selectedSet = useMemo(() => new Set(selectedValues), [selectedValues])

  const triggerLabel = useMemo(() => {
    if (multiple) {
      return summarizeSelection(selectedValues, options, placeholder)
    }
    const match = options.find((option) => option.value === selectedValues[0])
    return match?.label ?? placeholder
  }, [multiple, options, placeholder, selectedValues])

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

  const emitSingle = (next: string) => {
    if (multiple) {
      return
    }
    props.onChange?.({ target: { value: next } })
    props.onValueChange?.(next || null)
    setOpen(false)
  }

  const emitMulti = (next: string[]) => {
    if (!multiple) {
      return
    }
    props.onChange?.({ target: { value: next } })
    props.onValueChange?.(next)
  }

  const toggleMulti = (value: string) => {
    const next = selectedSet.has(value)
      ? selectedValues.filter((item) => item !== value)
      : [...selectedValues, value]
    emitMulti(next)
  }

  const clearMulti = () => {
    emitMulti([])
  }

  return (
    <div
      ref={rootRef}
      className={cn(
        'flat-select-wrap',
        open && 'flat-select-wrap-open',
        disabled && 'flat-select-wrap-disabled',
        className,
      )}
    >
      <button
        type="button"
        className="flat-select-trigger"
        disabled={disabled}
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-controls={listId}
        onClick={() => {
          if (!disabled) {
            setOpen((current) => !current)
          }
        }}
      >
        <span
          className={cn(
            'flat-select-value',
            selectedValues.length === 0 && 'flat-select-value-placeholder',
          )}
        >
          {triggerLabel}
        </span>
        <ChevronDown className={cn('flat-select-chevron', open && 'flat-select-chevron-open')} />
      </button>

      {open && (
        <div className="flat-select-panel" role="presentation">
          <ul
            id={listId}
            className="flat-select-list"
            role="listbox"
            aria-multiselectable={multiple || undefined}
          >
            {options.map((option) => {
              const active = selectedSet.has(option.value)
              return (
                <li key={option.value} role="presentation">
                  <button
                    type="button"
                    role="option"
                    aria-selected={active}
                    className={cn('flat-select-option', active && 'flat-select-option-active')}
                    onClick={() => {
                      if (multiple) {
                        toggleMulti(option.value)
                      } else {
                        emitSingle(option.value)
                      }
                    }}
                  >
                    <span className="flat-select-option-label">{option.label}</span>
                    {active && (
                      <span className="flat-select-check" aria-hidden="true">
                        ✓
                      </span>
                    )}
                  </button>
                </li>
              )
            })}
          </ul>

          {multiple && selectedValues.length > 0 && (
            <div className="flat-select-panel-footer">
              <button type="button" className="flat-select-option flat-select-clear" onClick={clearMulti}>
                <span className="flat-select-option-label">Clear selection</span>
              </button>
            </div>
          )}
          {!multiple && props.clearable && selectedValues.length > 0 && (
            <div className="flat-select-panel-footer">
              <button type="button" className="flat-select-option flat-select-clear" onClick={() => emitSingle('')}>
                <span className="flat-select-option-label">Clear</span>
              </button>
            </div>
          )}
        </div>
      )}
    </div>
  )
}
