type LandingAuth = {
  clerkEnabled: boolean
  signedIn: boolean
  explorerReady: boolean
  needsWorkspace: boolean
}

export function landingAction(auth: LandingAuth) {
  if (auth.clerkEnabled) {
    if (!auth.signedIn) return { label: 'Create your companion', to: '/signup', earlyAccess: true }
    if (auth.needsWorkspace) return { label: 'Finish setup', to: '/setup', earlyAccess: false }
    return { label: 'Open Mission Control', to: '/home', earlyAccess: false }
  }
  return auth.explorerReady
    ? { label: 'Open Mission Control', to: '/home', earlyAccess: false }
    : { label: 'Connect your workspace', to: '/login', earlyAccess: false }
}
