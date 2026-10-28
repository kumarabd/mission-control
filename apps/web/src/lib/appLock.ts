const ENABLED_KEY = 'mission-control.app-lock.enabled'
const CREDENTIAL_KEY = 'mission-control.app-lock.credential'
const RP_NAME = 'Mission Control'

function randomBytes(length = 32): Uint8Array<ArrayBuffer> {
  const bytes = new Uint8Array(length)
  crypto.getRandomValues(bytes)
  return bytes
}

function toBase64Url(value: ArrayBuffer): string {
  const bytes = new Uint8Array(value)
  let binary = ''
  for (const byte of bytes) binary += String.fromCharCode(byte)
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

function fromBase64Url(value: string): ArrayBuffer {
  const padded = value.replace(/-/g, '+').replace(/_/g, '/')
  const binary = atob(padded.padEnd(Math.ceil(padded.length / 4) * 4, '='))
  const bytes = new Uint8Array(binary.length)
  for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index)
  return bytes.buffer
}

export function appLockCredentialId(): string | null {
  try {
    return localStorage.getItem(CREDENTIAL_KEY)
  } catch {
    return null
  }
}

export function isAppLockEnabled(): boolean {
  try {
    return localStorage.getItem(ENABLED_KEY) === 'true' && Boolean(localStorage.getItem(CREDENTIAL_KEY))
  } catch {
    return false
  }
}

export function clearAppLockStorage(): void {
  try {
    localStorage.removeItem(ENABLED_KEY)
    localStorage.removeItem(CREDENTIAL_KEY)
  } catch {
    /* storage can be unavailable in a private window */
  }
}

export async function platformAuthenticatorAvailable(): Promise<boolean> {
  if (typeof window === 'undefined' || !window.PublicKeyCredential) return false
  if (!window.isSecureContext) return false
  try {
    return await window.PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable()
  } catch {
    return false
  }
}

/**
 * Creates a local platform credential (Touch ID / Windows Hello / device
 * passcode). There is no server ceremony: this is a convenience lock for this
 * browser, not a replacement for signing in.
 */
export async function registerAppLock(userLabel: string): Promise<void> {
  if (typeof window === 'undefined' || !window.PublicKeyCredential) {
    throw new Error('This browser doesn’t support a fingerprint or device passcode.')
  }
  if (!window.isSecureContext) {
    throw new Error('Fingerprint lock needs HTTPS or localhost.')
  }
  if (!(await platformAuthenticatorAvailable())) {
    throw new Error('No fingerprint or device passcode is available on this device.')
  }
  const credential = await navigator.credentials.create({
    publicKey: {
      challenge: randomBytes(),
      rp: { name: RP_NAME },
      user: {
        id: randomBytes(16),
        name: userLabel || 'this-browser',
        displayName: userLabel || 'This browser',
      },
      pubKeyCredParams: [
        { type: 'public-key', alg: -7 },
        { type: 'public-key', alg: -257 },
      ],
      authenticatorSelection: {
        authenticatorAttachment: 'platform',
        userVerification: 'required',
        residentKey: 'preferred',
      },
      timeout: 60_000,
      attestation: 'none',
    },
  })
  if (!(credential instanceof PublicKeyCredential)) {
    throw new Error('The fingerprint wasn’t set up.')
  }
  try {
    localStorage.setItem(CREDENTIAL_KEY, toBase64Url(credential.rawId))
    localStorage.setItem(ENABLED_KEY, 'true')
  } catch {
    throw new Error('This browser wouldn’t store the lock. Try allowing site data.')
  }
}

export async function verifyAppLock(): Promise<boolean> {
  const credentialId = appLockCredentialId()
  if (!credentialId) return false
  const assertion = await navigator.credentials.get({
    publicKey: {
      challenge: randomBytes(),
      allowCredentials: [
        {
          id: fromBase64Url(credentialId),
          type: 'public-key',
          transports: ['internal'],
        },
      ],
      userVerification: 'required',
      timeout: 60_000,
    },
  })
  return assertion instanceof PublicKeyCredential
}
