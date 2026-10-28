import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { Button, Card, CardBody, CardHeader, EmptyState, toast } from '../../components/ui'
import { useConfirm } from '../../components/ui/Dialog'
import {
  API_KEY_STORAGE_KEY,
  TOKEN_STORAGE_KEY,
  createAPIKey,
  listAPIKeys,
  mintToken,
  revokeAPIKey,
} from '../../lib/api'
import { formatDateTime, formatRelative } from '../../lib/format'

function ShowOnce({ label, value }: { label: string; value: string }) {
  return (
    <div className="mt-3 rounded-sm border border-flat-warning/40 bg-flat-warning-muted p-3">
      <p className="text-2xs font-medium text-flat-warning">{label} — copy now, shown once</p>
      <div className="mt-1.5 flex items-center gap-2">
        <code className="min-w-0 flex-1 truncate rounded-xs bg-flat-muted px-2 py-1 font-mono text-xs text-flat-foreground">
          {value}
        </code>
        <Button
          size="sm"
          variant="ghost"
          onClick={() => {
            void navigator.clipboard.writeText(value)
            toast.success('Copied')
          }}
        >
          Copy
        </Button>
      </div>
    </div>
  )
}

export default function SettingsApiKeys() {
  const qc = useQueryClient()
  const confirm = useConfirm()
  const keys = useQuery({ queryKey: ['settings-api-keys'], queryFn: listAPIKeys })
  const [newKey, setNewKey] = useState<string | null>(null)
  const [newToken, setNewToken] = useState<string | null>(null)

  const genKey = useMutation({
    mutationFn: createAPIKey,
    onSuccess: (data) => {
      setNewKey(data.api_key)
      localStorage.setItem(API_KEY_STORAGE_KEY, data.api_key)
      toast.success('API key created')
      qc.invalidateQueries({ queryKey: ['settings-api-keys'] })
    },
    onError: (e: Error) => toast.error(e.message),
  })

  const revoke = useMutation({
    mutationFn: revokeAPIKey,
    onSuccess: () => {
      toast.success('API key revoked')
      qc.invalidateQueries({ queryKey: ['settings-api-keys'] })
    },
    onError: (e: Error) => toast.error(e.message),
  })

  const genToken = useMutation({
    mutationFn: () => mintToken(24),
    onSuccess: (data) => {
      setNewToken(data.token)
      localStorage.setItem(TOKEN_STORAGE_KEY, data.token)
      toast.success(`Token minted — expires ${formatDateTime(data.expires_at)}`)
    },
    onError: (e: Error) => toast.error(e.message),
  })

  const onRevoke = async (id: string, prefix: string) => {
    if (await confirm({ title: `Revoke key ${prefix}…?`, body: 'This cannot be undone.', confirmLabel: 'Revoke', tone: 'danger' })) {
      revoke.mutate(id)
    }
  }

  const list = keys.data?.keys ?? []

  return (
    <div className="space-y-4">
      <Card padding="none">
        <div className="p-4">
          <CardHeader
            title="API keys"
            description="Connect Cursor, Claude Code, or OpenClaw. Each key is shown once."
            actions={
              <Button size="sm" variant="outline" loading={genKey.isPending} onClick={() => genKey.mutate()}>
                Create API key
              </Button>
            }
          />
          {newKey && <ShowOnce label="API key" value={newKey} />}
        </div>
        {keys.isLoading ? (
          <p className="px-4 pb-4 text-sm text-flat-muted-fg">Loading…</p>
        ) : list.length === 0 ? (
          <EmptyState size="sm" title="No API keys yet" body="Create one to connect your tool." />
        ) : (
          <table className="w-full text-base">
            <thead>
              <tr className="border-y border-flat-border text-2xs text-flat-subtle-fg">
                <th className="px-4 py-2 text-left font-medium">Key</th>
                <th className="px-4 py-2 text-left font-medium">Created</th>
                <th className="px-4 py-2 text-left font-medium">Last used</th>
                <th className="px-4 py-2" />
              </tr>
            </thead>
            <tbody>
              {list.map((key) => (
                <tr key={key.id} className="border-b border-flat-border last:border-0">
                  <td className="px-4 py-2 font-mono text-sm">{key.prefix}…</td>
                  <td className="px-4 py-2 text-sm text-flat-muted-fg">{formatDateTime(key.created_at)}</td>
                  <td className="px-4 py-2 text-sm text-flat-muted-fg">
                    {key.last_used_at ? formatRelative(key.last_used_at) : 'Never'}
                  </td>
                  <td className="px-4 py-2 text-right">
                    <Button
                      size="sm"
                      variant="ghost"
                      className="text-flat-danger"
                      onClick={() => onRevoke(key.id, key.prefix)}
                    >
                      Revoke
                    </Button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>

      <Card>
        <CardHeader
          title="JWT token"
          description="A 24-hour sign-in token for deployments that use token auth."
          actions={
            <Button size="sm" variant="outline" loading={genToken.isPending} onClick={() => genToken.mutate()}>
              Mint 24h token
            </Button>
          }
        />
        {newToken && (
          <CardBody>
            <ShowOnce label="Token" value={newToken} />
          </CardBody>
        )}
      </Card>
    </div>
  )
}
