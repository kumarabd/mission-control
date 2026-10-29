import { lazy, Suspense } from 'react'
import { Navigate, Route, Routes } from 'react-router-dom'
import { ProtectedRoute } from './auth/AuthProvider'
import { RealAuthProvider } from './auth/RealAuthProvider'
import { AppLockProvider } from './app-lock/AppLockProvider'
import { LEGACY_REDIRECTS } from './lib/navigation'

const AuditLog = lazy(() => import('./pages/AuditLog'))
const Today = lazy(() => import('./pages/Today'))
const Life = lazy(() => import('./pages/Life'))
const MissionMemory = lazy(() => import('./pages/MissionMemory'))
const MemoryDetail = lazy(() => import('./pages/MemoryDetail'))
const MemoryEntity = lazy(() => import('./pages/MemoryEntity'))
const MemorySource = lazy(() => import('./pages/MemorySource'))
const NotificationsPage = lazy(() => import('./pages/Notifications'))
const SettingsHome = lazy(() => import('./pages/SettingsHome'))
const SettingsAdvanced = lazy(() => import('./pages/SettingsAdvanced'))
const Login = lazy(() => import('./pages/Login'))
const NewWorkspace = lazy(() => import('./pages/NewWorkspace'))
const NotYetAvailable = lazy(() => import('./pages/NotYetAvailable'))
const OpsLinks = lazy(() => import('./pages/OpsLinks'))
const RawTables = lazy(() => import('./pages/RawTables'))
const SignUpPage = lazy(() => import('./pages/SignUp'))
const ExternalConnections = lazy(() => import('./pages/ExternalConnections'))
const SettingsApiKeys = lazy(() => import('./pages/settings/SettingsApiKeys'))
const SettingsAppearance = lazy(() => import('./pages/settings/SettingsAppearance'))
const SettingsProfile = lazy(() => import('./pages/settings/SettingsProfile'))
const SettingsModels = lazy(() => import('./pages/settings/SettingsModels'))
const SettingsPersonas = lazy(() => import('./pages/settings/SettingsPersonas'))
const Layout = lazy(() => import('./components/Layout'))
const Chat = lazy(() => import('./pages/Chat'))
const VoiceProvider = lazy(() => import('./voice/VoiceProvider').then(module => ({ default: module.VoiceProvider })))
const SetupPreview = lazy(() => import('./features/onboarding/Preview'))
const TravelLayout = lazy(() => import('./travel/TravelLayout'))
const Finance = lazy(() => import('./pages/Finance'))
const PlanPanel = lazy(() => import('./travel/panels/PlanPanel'))
const FleetPanel = lazy(() => import('./travel/panels/FleetPanel'))
const VehiclePanel = lazy(() => import('./travel/panels/VehiclePanel'))
const TripsPanel = lazy(() => import('./travel/panels/TripsPanel'))
const DrivePanel = lazy(() => import('./travel/panels/DrivePanel'))

export default function AuthenticatedApp() {
  return (
    <RealAuthProvider>
      <Suspense fallback={null}>
        <Routes>
          <Route path="/login/*" element={<Login />} />
          <Route path="/signup/*" element={<SignUpPage />} />
          {/* Top-level, like /login — reachable without explorerReady ever
              becoming true, since a brand-new signup with no tenant_registry
              row is exactly the state ClerkProtected redirects here from
              (AuthProvider.tsx's needsWorkspace). */}
          <Route path="/setup" element={<NewWorkspace />} />
          {import.meta.env.DEV && <Route path="/setup-preview" element={<SetupPreview />} />}

          <Route
            element={
              <ProtectedRoute>
                <VoiceProvider>
                  <AppLockProvider>
                    <Layout />
                  </AppLockProvider>
                </VoiceProvider>
              </ProtectedRoute>
            }
          >
            <Route path="/today" element={<Today />} />

            <Route path="/life" element={<Life />} />

            <Route path="/chat" element={<Chat />} />

            <Route path="/finance" element={<Finance />} />

            <Route path="/travel" element={<TravelLayout />}>
              <Route index element={<Navigate to="/travel/plan" replace />} />
              <Route path="plan" element={<PlanPanel />} />
              <Route path="fleet" element={<FleetPanel />} />
              <Route path="fleet/:vin" element={<VehiclePanel />} />
              <Route path="trips" element={<TripsPanel />} />
              <Route path="trips/:id" element={<DrivePanel />} />
              <Route path="*" element={<Navigate to="/travel/plan" replace />} />
            </Route>

            <Route path="/memory" element={<MissionMemory />} />
            <Route path="/memory/entity/:entityId" element={<MemoryEntity />} />
            <Route path="/memory/:itemKey" element={<MemoryDetail />} />
            <Route path="/memory/:itemKey/source/:sourceId" element={<MemorySource />} />

            <Route path="/notifications" element={<NotificationsPage />} />

            <Route path="/settings" element={<SettingsHome />} />
            <Route path="/settings/account" element={<SettingsProfile />} />
            <Route path="/settings/agents" element={<SettingsPersonas />} />
            <Route path="/settings/models" element={<SettingsModels />} />
            <Route path="/settings/connections" element={<ExternalConnections />} />
            <Route path="/settings/appearance" element={<SettingsAppearance />} />
            <Route path="/settings/advanced" element={<SettingsAdvanced />} />
            <Route path="/settings/advanced/activity" element={<AuditLog />} />
            <Route path="/settings/advanced/health" element={<OpsLinks />} />
            <Route path="/settings/advanced/raw" element={<RawTables />} />
            <Route path="/settings/advanced/api-keys" element={<SettingsApiKeys />} />
            <Route path="/settings/advanced/usage" element={<NotYetAvailable feature="budget" />} />

            {LEGACY_REDIRECTS.map((redirect) => (
              <Route
                key={`${redirect.from}-${redirect.to}`}
                path={redirect.prefix ? `${redirect.from}/*` : redirect.from}
                element={<Navigate to={redirect.to} replace />}
              />
            ))}

            <Route path="*" element={<Navigate to="/today" replace />} />
          </Route>
        </Routes>
      </Suspense>
    </RealAuthProvider>
  )
}
