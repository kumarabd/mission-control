// The setup wizard's logic, kept free of React so it can be tested: what each step needs before "Continue", and the
// request the router's POST /onboard expects. Mirrors the Treasure and Garage apps' setup, step for step.
import { generateSecret, type LLMTier, type OnboardingSubmission } from '../../lib/onboarding'

export const STEPS = ['intelligence', 'security', 'memory', 'review'] as const
export type StepId = (typeof STEPS)[number]

export const STEP_TITLE: Record<StepId, string> = {
  intelligence: 'Intelligence',
  security: 'Security',
  memory: 'Memory',
  review: 'Review',
}

export const TIER_NAMES = ['fast', 'medium', 'expert'] as const
export type TierName = (typeof TIER_NAMES)[number]

export const TIER_INFO: Record<TierName, { label: string; description: string }> = {
  fast: { label: 'Fast', description: 'Quick, cheap calls for simple steps.' },
  medium: { label: 'Medium', description: 'The everyday model, also used for background memory extraction. Required.' },
  expert: { label: 'Expert', description: 'Your most capable model, for the hardest steps.' },
}

export type TierDraft = {
  enabled: boolean
  provider: LLMTier['provider']
  model: string
  apiKey: string
  baseURL: string
}

export function newTier(enabled = false): TierDraft {
  return { enabled, provider: 'openai', model: '', apiKey: '', baseURL: '' }
}

export function tierIsComplete(t: TierDraft): boolean {
  if (!t.enabled) return true
  const baseURLRequired = t.provider !== 'anthropic'
  return t.model.trim() !== '' && t.apiKey.trim() !== '' && (!baseURLRequired || t.baseURL.trim() !== '')
}

export const SECRET_NAMES = ['postgres', 'memoryDb', 'memoryApiKey', 'memorySigning', 'toolsDb'] as const
export type SecretName = (typeof SECRET_NAMES)[number]
export type Secrets = Record<SecretName, string>

export const SECRET_LABEL: Record<SecretName, string> = {
  postgres: 'Database',
  memoryDb: 'Memory database',
  memoryApiKey: 'Memory key',
  memorySigning: 'Memory signing',
  toolsDb: 'Tools database',
}

export function newSecrets(): Secrets {
  return { postgres: generateSecret(), memoryDb: generateSecret(), memoryApiKey: generateSecret(), memorySigning: generateSecret(), toolsDb: generateSecret() }
}

export type WizardState = {
  /** 'platform': the platform's own models (nothing sent); 'own': the tiers below. */
  intelligence: 'platform' | 'own'
  tiers: Record<TierName, TierDraft>
  secrets: Secrets
  usePlatformEmbedding: boolean
  embeddingKey: string
}

export function newWizardState(): WizardState {
  return {
    intelligence: 'platform',
    tiers: { fast: newTier(), medium: newTier(true), expert: newTier() },
    secrets: newSecrets(),
    usePlatformEmbedding: true,
    embeddingKey: '',
  }
}

export function canContinue(s: WizardState, step: StepId): boolean {
  switch (step) {
    case 'intelligence':
      return s.intelligence === 'platform' || (s.tiers.medium.enabled && TIER_NAMES.every((n) => tierIsComplete(s.tiers[n])))
    case 'security':
      return SECRET_NAMES.every((n) => s.secrets[n].trim() !== '')
    case 'memory':
      return s.usePlatformEmbedding || s.embeddingKey.trim() !== ''
    case 'review':
      return true
  }
}

export const canSubmit = (s: WizardState) => STEPS.every((step) => canContinue(s, step))

export function buildSubmission(s: WizardState): OnboardingSubmission {
  const llmTiers: Record<string, LLMTier> = {}
  if (s.intelligence === 'own') {
    for (const name of TIER_NAMES) {
      const t = s.tiers[name]
      if (t.enabled) llmTiers[name] = { provider: t.provider, model: t.model.trim(), apiKey: t.apiKey.trim(), baseURL: t.baseURL.trim() }
    }
  }
  return {
    llmTiers,
    postgresPassword: s.secrets.postgres,
    agentBrainDbPassword: s.secrets.memoryDb,
    agentBrainApiKey: s.secrets.memoryApiKey,
    agentBrainJwtSecret: s.secrets.memorySigning,
    mcpHubDbPassword: s.secrets.toolsDb,
    litellmApiKey: s.usePlatformEmbedding ? undefined : s.embeddingKey.trim(),
  }
}

// The workflow names each progress row after the activity that ran (activity.GetInfo's ActivityType.Name); these are the
// words for a person, in the order the workflow runs them.
export const STEP_KEYS = [
  'ValidateRequest',
  'RegisterTemporalNamespace',
  'CreateK8sNamespace',
  'StageTenantSecrets',
  'HelmInstallTenant',
  'RegisterSharedPoolNamespace',
  'HealthCheck',
  'CleanupStagedSecret',
] as const

export const STEP_LABEL: Record<string, string> = {
  ValidateRequest: 'Checking your details',
  RegisterTemporalNamespace: 'Reserving your space',
  CreateK8sNamespace: 'Building your private workspace',
  StageTenantSecrets: 'Sealing your credentials',
  HelmInstallTenant: 'Starting your services',
  RegisterSharedPoolNamespace: 'Connecting everything',
  HealthCheck: "Making sure it's healthy",
  CleanupStagedSecret: 'Tidying up',
}

/** 0..1 across the eight steps, so the progress mark can fill as the workspace is built. */
export function progressFraction(status: string, steps: { step: string; status: string }[]): number {
  if (status === 'completed') return 1
  const done = steps.filter((x) => x.status === 'done').length
  const running = steps.some((x) => x.status === 'running') ? 0.5 : 0
  return Math.min(0.97, (done + running) / STEP_KEYS.length)
}
