export type AgentPolicyEntry = {
  role: string
  rank: number
  max_signal_tier: number
  bypass_sync_check?: boolean
}

export type AgentsSettingsResponse = {
  user_id: string
  policy_path?: string
  storage?: string
  /** API may omit or null this when no agents exist — always normalize with agentsFromSettings(). */
  agents?: Record<string, AgentPolicyEntry> | null
  subject_write_acl?: Record<string, string[]>
  suggested_agent_id: string
}

/** Safe agents map (backend historically returned `agents: null`). */
export function agentsFromSettings(
  data: AgentsSettingsResponse | undefined,
): Record<string, AgentPolicyEntry> {
  const agents = data?.agents
  if (agents && typeof agents === 'object') {
    return agents
  }
  return {}
}

export type RegisterAgentRequest = {
  agent_id?: string
  role?: string
  rank?: number
  max_signal_tier?: number
  bypass_sync_check?: boolean
}

export type RegisterAgentResponse = {
  agent_id: string
  entry: AgentPolicyEntry
  message: string
}

export type APIKeyCreateResponse = {
  api_key: string
  user_id: string
  persistent: boolean
  message: string
}

export type APIKeyRow = {
  id: string
  prefix: string
  created_at: string
  last_used_at?: string | null
}

export type APIKeyListResponse = {
  keys: APIKeyRow[]
  persistent: boolean
  writable: boolean
}

export type TokenMintResponse = {
  token: string
  user_id: string
  expires_at: string
}

export type MeResponse = {
  user_id: string
  onboarding: {
    agent_registered: boolean
    agent_count: number
    has_api_key: boolean
    agents: Record<string, AgentPolicyEntry>
  }
}
