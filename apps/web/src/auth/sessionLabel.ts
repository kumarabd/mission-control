import { AGENT_ID_STORAGE_KEY } from '../lib/api'

type ClerkUserLike = {
  fullName?: string | null
  firstName?: string | null
  lastName?: string | null
  username?: string | null
  primaryEmailAddress?: { emailAddress?: string } | null
}

export function clerkDisplayName(user: ClerkUserLike | null | undefined): string | null {
  if (!user) return null

  const fullName = user.fullName?.trim()
  if (fullName) return fullName

  const firstName = user.firstName?.trim()
  const lastName = user.lastName?.trim()
  if (firstName && lastName) return `${firstName} ${lastName}`
  if (firstName) return firstName
  if (lastName) return lastName

  return null
}

export function resolveSessionLabel(options: {
  userId?: string | null
  clerkUser?: ClerkUserLike | null
}): string {
  const { userId, clerkUser } = options

  const name = clerkDisplayName(clerkUser)
  if (name) return name

  const username = clerkUser?.username?.trim()
  if (username) return username

  const email = clerkUser?.primaryEmailAddress?.emailAddress?.trim()
  if (email) return email

  const id = userId?.trim()
  if (id) return id

  const agentId = localStorage.getItem(AGENT_ID_STORAGE_KEY)?.trim()
  if (agentId) return agentId

  return 'Guest'
}
