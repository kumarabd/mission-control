/* eslint-disable react-refresh/only-export-components */
import type { ReactNode } from 'react'
import { createContext, useCallback, useContext, useRef, useState } from 'react'
import * as RadixDialog from '@radix-ui/react-dialog'
import { X } from 'lucide-react'
import { cn } from '../../lib/cn'
import Button from './Button'

type Size = 'sm' | 'md' | 'lg'
const sizes: Record<Size, string> = {
  sm: 'max-w-sm',
  md: 'max-w-lg',
  lg: 'max-w-2xl',
}

export type DialogProps = {
  open: boolean
  onOpenChange: (open: boolean) => void
  title: ReactNode
  description?: ReactNode
  size?: Size
  children?: ReactNode
  footer?: ReactNode
  dismissible?: boolean
  /** `responsive` is a native-style bottom sheet on phones and a centered panel above. */
  placement?: 'center' | 'responsive'
}

const overlayClass = 'fixed inset-0 z-50 bg-[var(--theme-scrim)]'

export default function Dialog({
  open,
  onOpenChange,
  title,
  description,
  size = 'md',
  children,
  footer,
  dismissible = true,
  placement = 'center',
}: DialogProps) {
  const contentRef = useRef<HTMLDivElement>(null)
  return (
    <RadixDialog.Root open={open} onOpenChange={onOpenChange}>
      <RadixDialog.Portal>
        <RadixDialog.Overlay className={overlayClass} />
        <RadixDialog.Content
          ref={contentRef}
          onOpenAutoFocus={(event) => {
            const target = contentRef.current?.querySelector<HTMLElement>('[data-autofocus]')
            if (!target) return
            event.preventDefault()
            target.focus()
          }}
          onEscapeKeyDown={(e) => !dismissible && e.preventDefault()}
          onPointerDownOutside={(e) => !dismissible && e.preventDefault()}
          className={cn(
            'fixed left-1/2 top-1/2 z-50 flex max-h-[90vh] w-[calc(100vw-2rem)] -translate-x-1/2 -translate-y-1/2 flex-col',
            'rounded-lg border border-flat-border bg-flat-surface shadow-3',
            sizes[size],
            placement === 'responsive' &&
              'max-sm:bottom-0 max-sm:top-auto max-sm:max-h-[88vh] max-sm:w-full max-sm:max-w-none max-sm:translate-y-0 max-sm:rounded-b-none max-sm:rounded-t-2xl',
          )}
        >
          <div className="flex items-start justify-between gap-3 border-b border-flat-border px-5 py-4">
            <div className="min-w-0">
              <RadixDialog.Title className="text-lg text-flat-foreground">{title}</RadixDialog.Title>
              {description && (
                <RadixDialog.Description className="mt-0.5 text-sm text-flat-muted-fg">
                  {description}
                </RadixDialog.Description>
              )}
            </div>
            {dismissible && (
              <RadixDialog.Close
                className="-mr-1 -mt-1 inline-flex size-7 shrink-0 items-center justify-center rounded-sm text-flat-muted-fg hover:bg-flat-muted hover:text-flat-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-flat-primary focus-visible:ring-offset-2 focus-visible:ring-offset-flat-surface"
                aria-label="Close"
              >
                <X className="size-4" />
              </RadixDialog.Close>
            )}
          </div>
          {children && <div className="min-h-0 flex-1 overflow-auto px-5 py-4">{children}</div>}
          {footer && (
            <div className="flex items-center justify-end gap-2 border-t border-flat-border px-5 py-3">
              {footer}
            </div>
          )}
        </RadixDialog.Content>
      </RadixDialog.Portal>
    </RadixDialog.Root>
  )
}

/* ---------- imperative confirm() ---------- */

type ConfirmOptions = {
  title: string
  body?: ReactNode
  confirmLabel?: string
  cancelLabel?: string
  tone?: 'default' | 'danger'
}

type ConfirmState = ConfirmOptions & { resolve: (v: boolean) => void }

const ConfirmContext = createContext<(o: ConfirmOptions) => Promise<boolean>>(() => Promise.resolve(false))

export function ConfirmProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<ConfirmState | null>(null)

  const confirm = useCallback((o: ConfirmOptions) => {
    return new Promise<boolean>((resolve) => setState({ ...o, resolve }))
  }, [])

  const close = (value: boolean) => {
    state?.resolve(value)
    setState(null)
  }

  return (
    <ConfirmContext.Provider value={confirm}>
      {children}
      <Dialog
        open={state !== null}
        onOpenChange={(o) => !o && close(false)}
        title={state?.title ?? ''}
        description={state?.body}
        size="sm"
        footer={
          <>
            <Button variant="ghost" size="sm" onClick={() => close(false)}>
              {state?.cancelLabel ?? 'Cancel'}
            </Button>
            <Button
              variant={state?.tone === 'danger' ? 'danger' : 'primary'}
              size="sm"
              onClick={() => close(true)}
            >
              {state?.confirmLabel ?? 'Confirm'}
            </Button>
          </>
        }
      />
    </ConfirmContext.Provider>
  )
}

export function useConfirm() {
  return useContext(ConfirmContext)
}
