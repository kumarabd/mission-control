import { useEffect } from 'react'
import * as RadixDialog from '@radix-ui/react-dialog'
import { X } from 'lucide-react'
import { useLocation } from 'react-router-dom'
import SideNav from './SideNav'

export default function MobileNav({
  open,
  onOpenChange,
  badges,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
  badges?: Record<string, number>
}) {
  const location = useLocation()
  useEffect(() => {
    onOpenChange(false)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [location.pathname])

  return (
    <RadixDialog.Root open={open} onOpenChange={onOpenChange}>
      <RadixDialog.Portal>
        <RadixDialog.Overlay className="fixed inset-0 z-50 bg-[var(--theme-scrim)] lg:hidden" />
        <RadixDialog.Content className="fixed inset-y-0 left-0 z-50 w-64 lg:hidden">
          <RadixDialog.Title className="sr-only">Navigation</RadixDialog.Title>
          <RadixDialog.Close
            className="absolute right-2 top-3 z-10 inline-flex size-7 items-center justify-center rounded-sm text-flat-muted-fg hover:bg-flat-muted"
            aria-label="Close navigation"
          >
            <X className="size-4" />
          </RadixDialog.Close>
          <SideNav mobile badges={badges} onNavigate={() => onOpenChange(false)} />
        </RadixDialog.Content>
      </RadixDialog.Portal>
    </RadixDialog.Root>
  )
}
