import { cn } from '../lib/cn'
import { useTheme } from '../theme/theme-context'

function SunIcon({ className }: { className?: string }) {
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
      <circle cx="12" cy="12" r="4" />
      <path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41" />
    </svg>
  )
}

function MoonIcon({ className }: { className?: string }) {
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
      <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" />
    </svg>
  )
}

type Props = {
  className?: string
  variant?: 'toggle' | 'segmented' | 'segmented-inline'
}

export default function ThemeSwitcher({ className, variant = 'toggle' }: Props) {
  const { theme, setTheme, toggleTheme } = useTheme()
  const isDark = theme === 'dark'

  if (variant === 'segmented' || variant === 'segmented-inline') {
    const buttons = (
      <>
        <button
          type="button"
          onClick={() => setTheme('light')}
          className={cn('sidebar-prefs-btn', theme === 'light' && 'sidebar-prefs-btn-active')}
          aria-pressed={theme === 'light'}
          aria-label="Light mode"
          title="Light mode"
        >
          <SunIcon className="h-4 w-4" />
        </button>
        <button
          type="button"
          onClick={() => setTheme('dark')}
          className={cn('sidebar-prefs-btn', theme === 'dark' && 'sidebar-prefs-btn-active')}
          aria-pressed={theme === 'dark'}
          aria-label="Dark mode"
          title="Dark mode"
        >
          <MoonIcon className="h-4 w-4" />
        </button>
      </>
    )

    if (variant === 'segmented-inline') {
      return buttons
    }

    return (
      <div className={cn('sidebar-prefs-bar', className)} role="group" aria-label="Color mode">
        {buttons}
      </div>
    )
  }

  return (
    <button
      type="button"
      onClick={toggleTheme}
      className={cn(
        'inline-flex h-10 w-10 items-center justify-center rounded-md',
        'bg-flat-muted text-flat-muted-fg',
        'transition-all duration-200 ease-out hover:scale-105 hover:bg-flat-tint hover:text-flat-foreground',
        'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-flat-primary focus-visible:ring-offset-2',
        className,
      )}
      aria-label={isDark ? 'Switch to light mode' : 'Switch to dark mode'}
      title={isDark ? 'Light mode' : 'Dark mode'}
    >
      {isDark ? <SunIcon className="h-5 w-5" /> : <MoonIcon className="h-5 w-5" />}
    </button>
  )
}
