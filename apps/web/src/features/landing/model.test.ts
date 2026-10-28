import { describe, expect, it } from 'vitest'
import { landingAction } from './model'

const signedOut = { clerkEnabled: true, signedIn: false, explorerReady: false, needsWorkspace: false }

describe('landing signup and workspace handoff', () => {
  it('takes a new visitor to signup rather than the console or a waitlist', () => {
    expect(landingAction(signedOut)).toEqual({ label: 'Create your companion', to: '/signup', earlyAccess: true })
  })

  it('resumes setup for a signed-in account without a workspace', () => {
    expect(landingAction({ ...signedOut, signedIn: true, needsWorkspace: true }).to).toBe('/setup')
  })

  it('takes a ready user home and lets protected routing resolve an account still loading', () => {
    for (const explorerReady of [true, false]) {
      expect(landingAction({ ...signedOut, signedIn: true, explorerReady }).to).toBe('/home')
    }
  })

  it('does not let stale workspace readiness override sign-out', () => {
    expect(landingAction({ ...signedOut, explorerReady: true, needsWorkspace: true }).to).toBe('/signup')
  })

  it('uses the existing credential login when Clerk signup is unavailable', () => {
    expect(landingAction({ ...signedOut, clerkEnabled: false })).toEqual({ label: 'Connect your workspace', to: '/login', earlyAccess: false })
    expect(landingAction({ ...signedOut, clerkEnabled: false, explorerReady: true }).to).toBe('/home')
  })
})
