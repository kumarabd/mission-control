import { useId } from 'react'
import { cn } from '../../lib/cn'

/**
 * The mark: a gem outline that traces itself in, and fills from the bottom as the workspace is built. `fill` is 0..1.
 * It is decoration (the page says the same thing in words), so it is hidden from assistive tech.
 */
export function GemMark({ fill = 1, trace = false, className }: { fill?: number; trace?: boolean; className?: string }) {
  // useId returns ":r1:"; the colons break url(#…) references in SVG.
  const id = useId().replace(/:/g, '')
  const outline = 'M30 0 L120 0 L150 40 L75 100 L0 40 Z'
  return (
    <svg viewBox="-2 -2 154 104" className={cn('block h-auto', className)} aria-hidden="true">
      <defs>
        <linearGradient id={`${id}-g`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="var(--color-flat-primary)" stopOpacity="0.55" />
          <stop offset="1" stopColor="var(--color-flat-primary)" />
        </linearGradient>
        <clipPath id={`${id}-c`}><path d={outline} /></clipPath>
      </defs>
      <path d={outline} fill="none" stroke="var(--color-flat-primary)" strokeOpacity="0.3" strokeWidth="1.5" strokeLinejoin="round" />
      <g clipPath={`url(#${id}-c)`}>
        <rect className="ob-fill" x="0" y="0" width="150" height="100" fill={`url(#${id}-g)`} style={{ transform: `scaleY(${fill})` }} />
      </g>
      <path d="M0 40 L150 40 M60 0 L45 40 L75 100 M90 0 L105 40 L75 100 M45 40 L105 40" fill="none" stroke="var(--color-flat-background)" strokeOpacity="0.55" strokeWidth="1" />
      <path d={outline} fill="none" stroke="var(--color-flat-primary)" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className={trace ? 'ob-trace' : undefined} style={{ ['--len' as string]: 380 }} />
    </svg>
  )
}
