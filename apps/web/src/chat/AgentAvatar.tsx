import { Sparkles } from 'lucide-react'
import { cn } from '../lib/cn'

export type AgentIdentity = { name: string; avatarUrl: string | null }

/** The selected agent's picture, or the assistant's mark when it has none. */
export function AgentAvatar({
  agent,
  size = 30,
  className,
}: {
  agent: AgentIdentity
  size?: number
  className?: string
}) {
  if (agent.avatarUrl) {
    return (
      <img
        src={agent.avatarUrl}
        alt=""
        width={size}
        height={size}
        className={cn('shrink-0 rounded-full object-cover', className)}
      />
    )
  }
  return (
    <span
      aria-hidden="true"
      style={{ width: size, height: size }}
      className={cn('grid shrink-0 place-items-center rounded-full bg-flat-tint text-flat-primary', className)}
    >
      <Sparkles style={{ width: size * 0.5, height: size * 0.5 }} strokeWidth={1.6} />
    </span>
  )
}
