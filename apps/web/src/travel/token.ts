/** Where the travel API client gets the signed-in user's Clerk session token. Set by TravelAuthBridge. */
type TokenGetter = () => Promise<string | null>

let getter: TokenGetter | null = null

export function setTokenGetter(g: TokenGetter | null): void {
  getter = g
}

export async function getAuthToken(): Promise<string | null> {
  return getter ? getter() : null
}
