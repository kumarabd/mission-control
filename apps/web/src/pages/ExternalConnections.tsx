import { useAuth } from '@clerk/clerk-react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowUpRight, Blocks, Bot, CarFront, HeartPulse, Wallet, Braces, CalendarDays, Check, ChevronLeft, Cloud, Database, FileText, GitBranch, KeyRound, Home, Link2, LoaderCircle, RefreshCw, ShieldCheck, Sparkles, TriangleAlert } from 'lucide-react'
import { useState, type CSSProperties } from 'react'
import { Link } from 'react-router-dom'
import { Badge, Button, Card, Dialog, EmptyState, Input, toast } from '../components/ui'
import Screen from '../components/mission/Screen'
import { clerkEnabled } from '../auth/clerk'
import { useExplorerAuth } from '../auth/context'
import { authorizeCatalogEntry, connectCatalogEntry, disconnectCatalogEntry, listCatalog, type CatalogItem } from '../lib/gateway'

type ConnectionStatus = 'available' | 'processing' | 'connected' | 'needs_authorization' | 'failed'

function connectionStatus(item: CatalogItem, connecting = false): ConnectionStatus {
  if (connecting) return 'processing'
  if (item.state === 'failed') return 'failed'
  if (item.state === 'needs_authorization') return 'needs_authorization'
  if (item.connected && item.state === 'ready') return 'connected'
  // A saved connection can still be indexing, or waiting for its first state update.
  return item.connected || item.state === 'indexing' ? 'processing' : 'available'
}

const STATUS_LABEL: Record<ConnectionStatus, string> = {
  available: 'Not connected', processing: 'Processing', connected: 'Connected',
  needs_authorization: 'Authorization needed', failed: 'Needs attention',
}

const CTA_LABEL: Record<ConnectionStatus, string> = {
  available: 'Connect', processing: 'Details', connected: 'Manage', needs_authorization: 'Authorize', failed: 'Retry',
}

const STATUS_TONE = {
  available: 'neutral', processing: 'accent', connected: 'success',
  needs_authorization: 'warning', failed: 'danger',
} as const

// Real logos for third-party connections (public/connection-icons). Monochrome ones are drawn through a mask so they
// follow the theme's text colour instead of rendering black on a dark card.
const BRAND_LOGOS: Record<string, { src: string; mono?: boolean }> = {
  notion: { src: '/connection-icons/notion.svg', mono: true },
  github: { src: '/connection-icons/github.svg', mono: true },
  grafana: { src: '/connection-icons/grafana.svg' },
  trek: { src: '/connection-icons/trek.svg' },
  abrp: { src: '/connection-icons/abrp.png' },
  exa: { src: '/connection-icons/exa.png' },
}

function SystemIcon({ item }: { item: CatalogItem }) {
  const name = `${item.name} ${item.display_name}`.toLowerCase()
  if (item.origin === 'in-house') {
    // In-house backends get a domain icon plus a corner mark, so they read as ours at a glance.
    const Glyph = name.includes('maps') ? CarFront : name.includes('finance') ? Wallet : name.includes('health') ? HeartPulse : Blocks
    return <span className="relative inline-flex"><Glyph className="size-5" /><Home className="absolute -bottom-1 -right-1.5 size-2.5 rounded-full bg-flat-surface text-flat-primary" aria-label="Built in-house" /></span>
  }
  const logo = BRAND_LOGOS[item.name]
  if (logo?.mono) return <span className="inline-block size-5 bg-current" style={{ maskImage: `url(${logo.src})`, WebkitMaskImage: `url(${logo.src})`, maskSize: 'contain', WebkitMaskSize: 'contain', maskRepeat: 'no-repeat', WebkitMaskRepeat: 'no-repeat', maskPosition: 'center', WebkitMaskPosition: 'center' }} role="img" aria-label={item.display_name} />
  if (logo) return <img src={logo.src} alt={item.display_name} className="size-5 rounded-[4px] object-contain" />
  if (name.includes('github')) return <GitBranch className="size-5" />
  if (name.includes('calendar')) return <CalendarDays className="size-5" />
  if (name.includes('notion') || name.includes('docs')) return <FileText className="size-5" />
  if (name.includes('database') || name.includes('snowflake')) return <Database className="size-5" />
  if (name.includes('code') || name.includes('developer')) return <Braces className="size-5" />
  if (name.includes('cloud') || name.includes('drive')) return <Cloud className="size-5" />
  if (item.auth_kind === 'oauth') return <ShieldCheck className="size-5" />
  if (item.auth_kind === 'header') return <KeyRound className="size-5" />
  return <Blocks className="size-5" />
}

function statusCopy(item: CatalogItem, status: ConnectionStatus): string {
  switch (status) {
    case 'connected': return `${item.tool_count ?? 0} tools are ready for your assistant.`
    case 'processing': return 'We are establishing the connection and discovering its available tools. This may take a moment.'
    case 'needs_authorization': return 'Finish authorization in a new tab. This connection will update when access is ready.'
    case 'failed': return 'We could not reach this system. Check access, then retry the connection.'
    case 'available': return item.auth_kind === 'none'
      ? 'Connect it when you are ready to let your assistant use it.'
      : 'Connect it securely. Credentials stay scoped to your workspace.'
  }
}

function ConnectionCard({ item, getToken, queryKey, index }: { item: CatalogItem; getToken: () => Promise<string | null>; queryKey: readonly string[]; index: number }) {
  const client = useQueryClient()
  const [open, setOpen] = useState(false)
  const [token, setToken] = useState('')
  const [clientId, setClientId] = useState('')
  const [clientSecret, setClientSecret] = useState('')
  const [scopes, setScopes] = useState('')
  const [authorizing, setAuthorizing] = useState(false)
  const isMachineOAuth = item.auth_kind === 'oauth' && item.oauth_grant_type === 'client_credentials'
  const connect = useMutation({
    mutationFn: () => connectCatalogEntry(getToken, item.name, { token: token.trim() || undefined, oauth: isMachineOAuth && (clientId.trim() || clientSecret.trim()) ? { client_id: clientId.trim(), client_secret: clientSecret.trim(), scopes: scopes.trim() || undefined } : undefined }),
    onMutate: async () => {
      await client.cancelQueries({ queryKey })
      const previous = client.getQueryData<{ items: CatalogItem[] }>(queryKey)
      client.setQueryData<{ items: CatalogItem[] }>(queryKey, (current) => current && {
        ...current,
        items: current.items.map((entry) => entry.name === item.name ? { ...entry, connected: true, state: 'indexing' } : entry),
      })
      return previous
    },
    onSuccess: (saved) => {
      setToken(''); setClientId(''); setClientSecret(''); setScopes('')
      client.setQueryData<{ items: CatalogItem[] }>(queryKey, (previous) => previous && {
        ...previous,
        items: previous.items.map((entry) => entry.name === item.name ? { ...entry, ...saved } : entry),
      })
      void client.invalidateQueries({ queryKey })
    },
    onError: (_error, _variables, previous) => {
      if (previous) client.setQueryData(queryKey, previous)
      toast.error('The connection could not be saved. Check your access and try again.')
    },
  })
  const status = connectionStatus(item, connect.isPending)
  const isProcessing = status === 'processing'
  const needsToken = item.auth_kind === 'header' && (status === 'available' || status === 'failed')
  const needsClientCredentials = isMachineOAuth && (status === 'available' || status === 'failed')
  const disconnect = useMutation({
    mutationFn: () => disconnectCatalogEntry(getToken, item.name),
    onSuccess: () => { toast.success(`${item.display_name} disconnected`); void client.invalidateQueries({ queryKey }) },
    onError: () => toast.error('The connection could not be removed. Refresh and try again.'),
  })
  const authorize = async () => {
    const popup = window.open('about:blank', '_blank')
    if (!popup) { toast.error('Allow pop-ups to authorize this connection.'); return }
    popup.opener = null
    setAuthorizing(true)
    try {
      const result = await authorizeCatalogEntry(getToken, item.name)
      const url = new URL(result.authorization_url)
      if (url.protocol !== 'https:') throw new Error('Invalid authorization URL')
      popup.location.replace(url.href)
    } catch { popup.close(); toast.error('Authorization is not available yet. Refresh and try again.') } finally { setAuthorizing(false) }
  }
  const busyMutation = connect.isPending || disconnect.isPending
  const style = { '--connection-card-delay': `${Math.min(index, 8) * 55}ms` } as CSSProperties
  const inputNote = item.connected ? '(leave blank to reuse the saved value)' : '(required)'

  return <>
    <Card padding="none" className={`external-system-card external-system-card--${status} overflow-hidden`} style={style}>
      <button type="button" className="external-system-body" onClick={() => setOpen(true)} aria-label={`${item.display_name}, ${STATUS_LABEL[status]}. View details`}>
        <span className="flex items-center gap-3">
          <span className={`external-system-icon external-system-icon--${status}`} aria-hidden><SystemIcon item={item} /></span>
          <span className="min-w-0 truncate text-[0.95rem] font-semibold leading-tight text-flat-foreground">{item.display_name}</span>
        </span>
        <span className="external-system-desc">{item.description || statusCopy(item, status)}</span>
        <span className="external-system-foot">
          <span className={`external-system-status external-system-status--${status}`}><span className={`status-dot status-dot--${status}`} aria-hidden />{STATUS_LABEL[status]}</span>
          <span className="external-system-cta">{status === 'connected' ? `${item.tool_count ?? 0} tools` : CTA_LABEL[status]}<ArrowUpRight className="size-3.5" aria-hidden /></span>
        </span>
      </button>
    </Card>
    <Dialog open={open} onOpenChange={setOpen} title={<span className="flex items-center gap-3"><span className={`external-system-icon external-system-icon--${status}`} aria-hidden><SystemIcon item={item} /></span>{item.display_name}</span>} description={item.description} footer={<>
      {item.connected && <Button size="sm" variant="ghost" disabled={busyMutation} onClick={() => { if (window.confirm(`Disconnect ${item.display_name}? Your assistant will lose access to its tools. Provider access is not revoked.`)) disconnect.mutate() }}>Disconnect</Button>}
      {status === 'needs_authorization' ? <Button size="sm" disabled={authorizing || busyMutation} loading={authorizing} onClick={() => void authorize()}>Authorize</Button>
        : (status === 'available' || status === 'failed') && <Button size="sm" iconLeft={status === 'failed' ? <RefreshCw className="size-3.5" /> : <Link2 className="size-3.5" />} disabled={busyMutation || (needsToken && !item.connected && !token.trim()) || (needsClientCredentials && !item.connected && !(clientId.trim() && clientSecret.trim()))} loading={connect.isPending} onClick={() => connect.mutate()}>{status === 'failed' ? 'Retry connection' : 'Connect'}</Button>}
    </>}>
      <div className="space-y-4">
        <div><Badge tone={STATUS_TONE[status]}><span className={`status-dot status-dot--${status}`} aria-hidden />{STATUS_LABEL[status]}</Badge>
          <p className="mt-2 text-sm text-flat-muted-fg" role="status" aria-live="polite">{isProcessing && <LoaderCircle className="mr-2 inline size-3.5 animate-spin text-flat-primary" aria-hidden />}{statusCopy(item, status)}</p></div>
        <div className="flex flex-wrap gap-1.5 text-xs">
          <span className="external-system-meta">{item.auth_kind === 'oauth' ? <ShieldCheck className="size-3.5" /> : item.auth_kind === 'header' ? <KeyRound className="size-3.5" /> : <Check className="size-3.5" />}{item.auth_kind === 'oauth' ? 'Secure account connection' : item.auth_kind === 'header' ? 'Token-based access' : item.shared ? 'Shared platform account' : 'No credentials required'}</span>
          {item.origin === 'in-house' && <span className="external-system-meta"><Home className="size-3.5" />Built in-house</span>}
          {status === 'connected' && <span className="external-system-meta"><Bot className="size-3.5" />{item.tool_count ?? 0} tools</span>}
        </div>
        {needsToken && <label className="block text-sm font-medium text-flat-foreground">Access token <span className="font-normal text-flat-muted-fg">{inputNote}</span><Input className="mt-2" type="password" autoComplete="new-password" spellCheck={false} value={token} disabled={busyMutation} onChange={(event) => setToken(event.target.value)} /><span className="mt-2 block text-xs font-normal leading-5 text-flat-subtle-fg">Use a token restricted to only what your assistant needs.</span></label>}
        {needsClientCredentials && <div className="grid gap-3">
          <label className="text-sm font-medium text-flat-foreground">Client ID <span className="font-normal text-flat-muted-fg">{inputNote}</span><Input className="mt-2" autoComplete="off" spellCheck={false} value={clientId} disabled={busyMutation} onChange={(event) => setClientId(event.target.value)} /></label>
          <label className="text-sm font-medium text-flat-foreground">Client secret <span className="font-normal text-flat-muted-fg">{inputNote}</span><Input className="mt-2" type="password" autoComplete="new-password" spellCheck={false} value={clientSecret} disabled={busyMutation} onChange={(event) => setClientSecret(event.target.value)} /></label>
          <label className="text-sm font-medium text-flat-foreground">Scopes <span className="font-normal text-flat-muted-fg">(optional)</span><Input className="mt-2" autoComplete="off" spellCheck={false} placeholder="space-separated" value={scopes} disabled={busyMutation} onChange={(event) => setScopes(event.target.value)} /></label>
        </div>}
      </div>
    </Dialog>
  </>
}

function ConnectionsSkeleton() { return <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3" aria-label="Loading external systems">{Array.from({ length: 6 }, (_, index) => <div key={index} className="h-36 animate-pulse rounded-xl border border-flat-border bg-flat-surface" />)}</div> }

function ConnectionsList() {
  const { getToken } = useAuth()
  const { explorerReady, userId } = useExplorerAuth()
  const tokenGetter = () => getToken()
  const queryKey = ['external-connections', userId ?? '']
  const query = useQuery({ queryKey, queryFn: () => listCatalog(tokenGetter), enabled: explorerReady, refetchInterval: 5000 })
  const items = query.data?.items ?? []
  const groups = ([
    ['Needs attention', (st: ConnectionStatus) => st === 'failed' || st === 'needs_authorization'],
    ['Processing', (st: ConnectionStatus) => st === 'processing'],
    ['Connected', (st: ConnectionStatus) => st === 'connected'],
    ['Available', (st: ConnectionStatus) => st === 'available'],
  ] as const).map(([label, match]) => ({ label, items: items.filter((item) => match(connectionStatus(item))) })).filter((group) => group.items.length > 0)
  return (
    <Screen
      eyebrow={
        <Link
          to="/settings"
          className="inline-flex items-center gap-1 text-flat-muted-fg hover:text-flat-foreground"
        >
          <ChevronLeft className="size-3.5" aria-hidden />
          Settings
        </Link>
      }
      title="Connections"
      description="The apps and accounts your assistant can use. You choose what it can reach."
      actions={
        <Button
          size="md"
          variant="secondary"
          disabled={!explorerReady || query.isFetching}
          iconLeft={
            <RefreshCw
              className={`size-4 ${query.isFetching ? 'animate-spin motion-reduce:animate-none' : ''}`}
            />
          }
          onClick={() => void query.refetch()}
        >
          Refresh
        </Button>
      }
    >
      <div className="space-y-6">
    {!explorerReady ? <p className="text-sm text-flat-muted-fg">Loading workspace…</p>
      : query.isLoading ? <ConnectionsSkeleton />
      : query.isError ? <EmptyState icon={<TriangleAlert />} title="Couldn't load connections" body="Check that your workspace is set up, then refresh." action={{ label: 'Try again', onClick: () => void query.refetch() }} />
      : items.length === 0 ? <EmptyState icon={<Sparkles />} title="No connections available yet" body="Reviewed integrations will appear here when they are enabled for your workspace." />
      : groups.map((group) => <section key={group.label} aria-labelledby={`conn-${group.label}`} className="space-y-3">
        <h2 id={`conn-${group.label}`} className="flex items-baseline gap-2 text-sm font-semibold text-flat-foreground">{group.label}<span className="text-xs font-normal tabular-nums text-flat-muted-fg">{group.items.length}</span></h2>
        <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">{group.items.map((item, index) => <ConnectionCard key={item.name} item={item} getToken={tokenGetter} queryKey={queryKey} index={index} />)}</div>
      </section>)}
      </div>
    </Screen>
  )
}

export default function ExternalConnections() { return clerkEnabled ? <ConnectionsList /> : <EmptyState icon={<ShieldCheck />} title="Sign-in is required" body="External connections are configured per workspace." /> }
