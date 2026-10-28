import type { ReactNode } from 'react'
import { Link } from 'react-router-dom'
import ThemeSwitcher from './ThemeSwitcher'

/** Brand on the left, theme toggle on the right. Shared by sign-in, sign-up and workspace setup. */
export function AuthHeader() {
  return (
    <header className="flex items-center justify-between px-6 py-5 sm:px-10">
      <Link to="/" className="flex items-center gap-2.5 text-base font-medium tracking-tight text-flat-foreground no-underline hover:no-underline">
        <img src="/logo-mark.svg" alt="" width={24} height={24} />
        MissionControl
      </Link>
      <ThemeSwitcher />
    </header>
  )
}

/** Quiet, centred frame for sign-in and sign-up. */
export default function AuthShell({ title, description, children }: { title: string; description: string; children: ReactNode }) {
  return (
    <div className="flex min-h-screen flex-col bg-flat-background text-flat-foreground">
      <AuthHeader />
      <main className="mx-auto flex w-full max-w-md flex-1 flex-col items-center justify-center px-5 pb-24 text-center">
        <h1 className="text-[clamp(2rem,4vw,2.8rem)] font-normal leading-[1.08] tracking-[-0.03em]">{title}</h1>
        <p className="mt-3 text-base text-flat-muted-fg">{description}</p>
        <div className="mt-9 flex w-full justify-center">{children}</div>
      </main>
    </div>
  )
}
