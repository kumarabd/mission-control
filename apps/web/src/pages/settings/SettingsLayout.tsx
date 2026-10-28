import { Outlet } from 'react-router-dom'
import { PageHeader, RoutedTabs } from '../../components/ui'

export default function SettingsLayout() {
  return (
    <div className="space-y-6">
      <PageHeader title="Settings" />
      <RoutedTabs
        items={[
          { to: '/settings/profile', label: 'Profile' },
          { to: '/settings/models', label: 'Models' },
          { to: '/settings/api-keys', label: 'API keys' },
          { to: '/settings/personas', label: 'Personas' },
          { to: '/settings/appearance', label: 'Appearance' },
        ]}
      />
      <Outlet />
    </div>
  )
}
