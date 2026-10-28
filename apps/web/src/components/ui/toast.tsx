/* eslint-disable react-refresh/only-export-components */
import { Toaster as SonnerToaster, toast } from 'sonner'
import { useTheme } from '../../theme/theme-context'

export { toast }

export function Toaster() {
  const { theme } = useTheme()
  return (
    <SonnerToaster
      position="bottom-right"
      theme={theme}
      toastOptions={{
        classNames: {
          toast:
            'border border-flat-border bg-flat-surface-raised text-flat-foreground text-sm rounded-md shadow-2',
          description: 'text-flat-muted-fg',
          actionButton: 'bg-flat-primary text-flat-on-primary',
          cancelButton: 'bg-flat-muted text-flat-muted-fg',
        },
      }}
    />
  )
}
