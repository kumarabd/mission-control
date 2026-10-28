import { useState } from 'react'
import { Outlet, useLocation } from 'react-router-dom'
import { cn } from '../lib/cn'
import LifeBootstrap from '../lib/life/bootstrap'
import BottomNav from './shell/BottomNav'
import CommandPalette from './shell/CommandPalette'
import MobileNav from './shell/MobileNav'
import SideNav from './shell/SideNav'
import TopBar from './shell/TopBar'
import { useSidebarCollapsed } from './shell/useSidebar'

const FULL_BLEED = new Set(['/chat'])
/** Planning is a docked panel beside a map: it fills the page. The other Travel pages sit in the centred column. */
const isFullBleed = (path: string) => FULL_BLEED.has(path) || path === '/travel/plan'

export default function Layout() {
  const location = useLocation()
  const { collapsed, toggle } = useSidebarCollapsed()
  const [mobileNav, setMobileNav] = useState(false)
  const [command, setCommand] = useState(false)

  const fullBleed = isFullBleed(location.pathname)

  return (
    <div className="flex h-screen w-full overflow-hidden bg-flat-background text-flat-foreground">
      <LifeBootstrap />
      <aside className="hidden shrink-0 lg:block">
        <SideNav collapsed={collapsed} onToggleCollapsed={toggle} />
      </aside>

      <MobileNav open={mobileNav} onOpenChange={setMobileNav} />

      <div className="flex min-w-0 flex-1 flex-col">
        <TopBar onOpenCommand={() => setCommand(true)} />
        <main
          className={cn(
            'min-h-0 flex-1',
            fullBleed ? 'overflow-hidden' : 'overflow-y-auto',
          )}
        >
          {fullBleed ? (
            <Outlet />
          ) : (
            <div className="mx-auto w-full max-w-[1080px] px-4 py-8 sm:px-8 lg:px-12 lg:py-10">
              <Outlet />
            </div>
          )}
        </main>
        <BottomNav onOpenMore={() => setMobileNav(true)} />
      </div>

      <CommandPalette open={command} onOpenChange={setCommand} />
    </div>
  )
}
