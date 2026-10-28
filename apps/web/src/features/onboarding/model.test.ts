import { describe, expect, it } from 'vitest'
import {
  buildSubmission,
  canContinue,
  canSubmit,
  newWizardState,
  newTier,
  progressFraction,
  STEP_KEYS,
  STEP_LABEL,
  tierIsComplete,
} from './model'

describe('setup wizard model', () => {
  it('the default path needs no keys and sends no models', () => {
    const s = newWizardState()
    expect(canSubmit(s)).toBe(true)
    const sub = buildSubmission(s)
    expect(sub.llmTiers).toEqual({})
    expect(sub.litellmApiKey).toBeUndefined()
  })

  it('bring-your-own needs the required medium tier complete, and any other enabled tier too', () => {
    const s = newWizardState()
    s.intelligence = 'own'
    expect(canContinue(s, 'intelligence')).toBe(false)
    s.tiers.medium = { ...newTier(true), model: 'gpt-4o-mini', apiKey: 'sk-x' }
    expect(canContinue(s, 'intelligence')).toBe(false) // OpenAI-compatible also needs a base URL
    s.tiers.medium.baseURL = 'https://api.example.com/v1'
    expect(canContinue(s, 'intelligence')).toBe(true)
    s.tiers.fast = newTier(true)
    expect(canContinue(s, 'intelligence')).toBe(false)
    s.tiers.fast = newTier(false)
    expect(buildSubmission(s).llmTiers).toEqual({
      medium: { provider: 'openai', model: 'gpt-4o-mini', apiKey: 'sk-x', baseURL: 'https://api.example.com/v1' },
    })
  })

  it('Anthropic does not need a base URL', () => {
    expect(tierIsComplete({ ...newTier(true), provider: 'anthropic', model: 'm', apiKey: 'k' })).toBe(true)
    expect(tierIsComplete({ ...newTier(true), provider: 'openai', model: 'm', apiKey: 'k' })).toBe(false)
  })

  it('your own embedding endpoint needs a key, which is trimmed', () => {
    const s = newWizardState()
    s.usePlatformEmbedding = false
    expect(canContinue(s, 'memory')).toBe(false)
    s.embeddingKey = '  abc '
    expect(canContinue(s, 'memory')).toBe(true)
    expect(buildSubmission(s).litellmApiKey).toBe('abc')
  })

  it('generated credentials are long, random and distinct, and all required', () => {
    const a = newWizardState().secrets
    const values = Object.values(a)
    expect(values).toHaveLength(5)
    expect(new Set(values).size).toBe(5)
    expect(values.every((v) => v.length >= 24)).toBe(true)
    expect(newWizardState().secrets.postgres).not.toBe(a.postgres)
    const s = newWizardState()
    s.secrets.toolsDb = '  '
    expect(canContinue(s, 'security')).toBe(false)
  })

  it('has no Discord step or field', () => {
    expect(Object.keys(buildSubmission(newWizardState()))).not.toContain('discordBotToken')
  })

  it('progress fills as steps finish, and every reported step has words', () => {
    expect(
      progressFraction('running', [
        { step: 'ValidateRequest', status: 'done' },
        { step: 'RegisterTemporalNamespace', status: 'done' },
        { step: 'CreateK8sNamespace', status: 'running' },
      ]),
    ).toBeCloseTo(2.5 / 8)
    expect(progressFraction('completed', [])).toBe(1)
    expect(STEP_KEYS.every((k) => STEP_LABEL[k])).toBe(true)
  })
})
