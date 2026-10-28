import type { LucideIcon } from 'lucide-react'
import { cn } from '../../lib/cn'
import { TONE, type MissionTone } from './tones'

export default function IconBadge({
  icon: Icon,
  tone = 'focus',
  size = 'md',
  className,
}: {
  icon: LucideIcon
  tone?: MissionTone
  size?: 'sm' | 'md' | 'lg'
  className?: string
}) {
  const t = TONE[tone]
  const box = size === 'sm' ? 'size-8 rounded-[10px]' : size === 'lg' ? 'size-12 rounded-[14px]' : 'size-10 rounded-[12px]'
  const glyph = size === 'sm' ? 'size-4' : size === 'lg' ? 'size-6' : 'size-5'
  return (
    <span className={cn('inline-flex shrink-0 items-center justify-center border', box, t.bg, t.border, t.text, className)}>
      <Icon className={glyph} aria-hidden />
    </span>
  )
}
