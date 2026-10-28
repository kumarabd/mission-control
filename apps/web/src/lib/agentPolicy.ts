import type { AgentPolicyEntry } from './settingsTypes'

export const AGENT_ROLES = [
  { value: 'assistant', label: 'Assistant', description: 'Standard memory writes.' },
  { value: 'trusted', label: 'Trusted', description: 'Higher priority; can write important facts.' },
  { value: 'scraper', label: 'Scraper', description: 'Automated ingestion with standard limits.' },
  { value: 'readonly', label: 'Read-only', description: 'Can recall memories but not write.' },
] as const

export const SIGNAL_TIER_LABELS: Record<number, string> = {
  0: 'No writes',
  1: 'Important facts only',
  2: 'All memory types',
}

export function defaultMaxTierForRole(role: string): number {
  switch (role) {
    case 'trusted':
      return 1
    case 'readonly':
      return 0
    default:
      return 2
  }
}

export function formatBypassSync(entry: AgentPolicyEntry): string {
  return entry.bypass_sync_check ? 'Yes' : 'No'
}

export type ACLRow = {
  domain: string
  agents: string
}

export function aclFromMap(acl: Record<string, string[]> | undefined): ACLRow[] {
  if (!acl || typeof acl !== 'object') return []
  return Object.entries(acl)
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([domain, agents]) => ({
      domain,
      agents: agents.join(', '),
    }))
}

export function aclToMap(rows: ACLRow[]): Record<string, string[]> {
  const out: Record<string, string[]> = {}
  for (const row of rows) {
    const domain = row.domain.trim()
    if (!domain) continue
    const agents = row.agents
      .split(',')
      .map((a) => a.trim())
      .filter(Boolean)
    if (agents.length > 0) {
      out[domain] = agents
    }
  }
  return out
}
