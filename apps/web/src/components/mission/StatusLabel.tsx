import { cn } from '../../lib/cn'
import { TONE, type MissionTone } from './tones'

/** Symbol + label + colour; never colour alone. */
export default function StatusLabel({
  tone,
  label,
  className,
}: {
  tone: MissionTone
  label?: string
  className?: string
}) {
  const t = TONE[tone]
  const Icon = t.icon
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1.5 font-mono text-2xs uppercase tracking-[0.06em]',
        t.text,
        className,
      )}
    >
      <Icon className="size-3.5 shrink-0" aria-hidden />
      <span>{label ?? t.label}</span>
    </span>
  )
}
