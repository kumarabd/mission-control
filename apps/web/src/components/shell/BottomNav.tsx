import { Ellipsis } from 'lucide-react'
import { Link, useLocation } from 'react-router-dom'
import { cn } from '../../lib/cn'
import { isNavActive, type NavItem } from '../../lib/navigation'
import { NavIcon } from './navIcons'

const ITEMS: NavItem[] = [
  { to: '/today', label: 'Today', icon: 'home' },
  { to: '/goals', label: 'Goals', icon: 'target', matchPrefix: '/goals' },
  { to: '/chat', label: 'Chat', icon: 'message-square' },
  { to: '/memory', label: 'Memory', icon: 'brain', matchPrefix: '/memory' },
]

const tab =
  'flex min-w-0 flex-1 flex-col items-center justify-center gap-0.5 py-2 text-2xs font-medium no-underline transition-colors hover:no-underline'

/** The phone's main navigation: four places you go every day, plus "More" for the full menu. */
export default function BottomNav({ onOpenMore }: { onOpenMore: () => void }) {
  const { pathname } = useLocation()
  return (
    <nav
      aria-label="Main"
      className="flex shrink-0 border-t border-flat-border bg-flat-tint-soft pb-[env(safe-area-inset-bottom)] lg:hidden"
    >
      {ITEMS.map((item) => {
        const active = isNavActive(pathname, item)
        return (
          <Link
            key={item.to}
            to={item.to}
            aria-current={active ? 'page' : undefined}
            className={cn(tab, active ? 'text-flat-primary' : 'text-flat-subtle-fg hover:text-flat-foreground')}
          >
            <NavIcon name={item.icon} className="size-5" />
            <span className="truncate">{item.label}</span>
          </Link>
        )
      })}
      <button
        type="button"
        onClick={onOpenMore}
        aria-haspopup="dialog"
        className={cn(tab, 'text-flat-subtle-fg hover:text-flat-foreground')}
      >
        <Ellipsis className="size-5" aria-hidden />
        <span>More</span>
      </button>
    </nav>
  )
}
