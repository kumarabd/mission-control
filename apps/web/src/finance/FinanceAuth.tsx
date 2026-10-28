import { useAuth } from '@clerk/clerk-react'
import { useMemo, type ReactNode } from 'react'
import { clerkEnabled } from '../auth/clerk'
import { EmptyState, PageSkeleton } from '../components/ui'
import { createFinanceAPI, type FinanceAPI } from './api'

type Props = { children: (api: FinanceAPI, userId: string) => ReactNode }

function ClerkFinance({ children }: Props) {
  const { getToken, isLoaded, isSignedIn, userId } = useAuth()
  // The token getter belongs to this session, rather than a mutable global bridge.
  const api = useMemo(() => createFinanceAPI((skipCache) => getToken({ skipCache })), [getToken])
  if (!isLoaded) return <PageSkeleton />
  if (!isSignedIn || !userId) return <EmptyState title="Sign in to view your finances" action={{ label: 'Sign in', to: '/login' }} />
  return children(api, userId)
}

export function FinanceAuth({ children }: Props) {
  if (!clerkEnabled) return <EmptyState title="Finance requires sign-in" body="Configure Clerk sign-in to access your finances through the router." />
  return <ClerkFinance>{children}</ClerkFinance>
}
