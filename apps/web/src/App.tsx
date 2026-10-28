import { lazy, Suspense } from 'react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { clerkEnabled } from './auth/clerk'
import { AuthContext, type AuthContextValue } from './auth/context'
import { ConfirmProvider } from './components/ui/Dialog'
import { Toaster } from './components/ui/toast'
import { ThemeProvider } from './theme/ThemeProvider'
import AppErrorBoundary from './components/AppErrorBoundary'
import Landing from './pages/Landing'
import Slides from './pages/Slides'

const Privacy = lazy(() => import('./pages/Privacy'))
const Capabilities = lazy(() => import('./pages/Capabilities'))
const Support = lazy(() => import('./pages/Support'))
// The console, settings and record views, plus Clerk, load only on demand.
// The public landing's first paint does not pay for any of it.
const AuthenticatedApp = lazy(() => import('./AuthenticatedApp'))
// The docs surface is lazy so the markdown corpus and its renderer stay out of
// the landing bundle.
const DocsLayout = lazy(() => import('./docs/DocsLayout'))
const DocsIndex = lazy(() => import('./docs/DocsIndex'))
const DocsArticle = lazy(() => import('./docs/DocsArticle'))
const TreasureLayout = lazy(() => import('./treasure/TreasureLayout'))
const TreasureLanding = lazy(() => import('./treasure/TreasureLanding'))
const TreasureSupport = lazy(() => import('./treasure/TreasureSupport'))
const TreasurePrivacy = lazy(() => import('./treasure/TreasurePrivacy'))
const Garage = lazy(() => import('./pages/Garage'))

const queryClient = new QueryClient({
  defaultOptions: {
    queries: { staleTime: 15_000, gcTime: 300_000, retry: 1, refetchOnWindowFocus: false },
  },
})

// Public routes do not initialize Clerk. New visitors see the signup CTA; a
// signed-in visitor can still use Log in, and /signup resolves the live session.
const PUBLIC_AUTH: AuthContextValue = {
  clerkEnabled,
  signedIn: false,
  explorerReady: false,
  needsWorkspace: false,
  userId: null,
  sessionLabel: '',
  refreshExplorerToken: async () => {},
  signOutExplorer: () => {},
}

function PublicRoutes() {
  return (
    <AuthContext.Provider value={PUBLIC_AUTH}>
      <Suspense fallback={null}>
        <Routes>
          <Route path="/" element={<Landing />} />
          <Route path="/slides" element={<Slides />} />
          <Route path="/privacy" element={<Privacy />} />
          <Route path="/capabilities" element={<Capabilities />} />
          <Route path="/support" element={<Support />} />
          <Route path="/garage/*" element={<Garage />} />
          {/* Concepts and architecture, authored as markdown in /docs. Public: a
              page worth linking to should not need an account to read. */}
          <Route path="/docs" element={<DocsLayout />}>
            <Route index element={<DocsIndex />} />
            <Route path="*" element={<DocsArticle />} />
          </Route>
          {/* Public Treasure pages: the landing page, plus the support and privacy URLs given to the App Store. */}
          <Route path="/treasure" element={<TreasureLayout />}>
            <Route index element={<TreasureLanding />} />
            <Route path="support" element={<TreasureSupport />} />
            <Route path="privacy" element={<TreasurePrivacy />} />
            <Route path="*" element={<Navigate to="/treasure" replace />} />
          </Route>

          <Route path="/*" element={<AuthenticatedApp />} />
        </Routes>
      </Suspense>
    </AuthContext.Provider>
  )
}

export default function App() {
  return (
    <ThemeProvider>
      <AppErrorBoundary>
        <ConfirmProvider>
          <QueryClientProvider client={queryClient}>
            <BrowserRouter basename={import.meta.env.BASE_URL}>
              <PublicRoutes />
            </BrowserRouter>
          </QueryClientProvider>
          <Toaster />
        </ConfirmProvider>
      </AppErrorBoundary>
    </ThemeProvider>
  )
}
