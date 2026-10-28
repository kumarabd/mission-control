import { useAuth } from '@clerk/clerk-react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { Link } from 'react-router-dom'
import { ChevronLeft } from 'lucide-react'
import { Badge, Button, Dialog, EmptyState, Field, Input, Textarea, toast } from '../../components/ui'
import { useConfirm } from '../../components/ui/Dialog'
import Screen from '../../components/mission/Screen'
import ListCard from '../../components/mission/ListCard'
import { createPersona, listPersonas, updatePersona, SELECTED_PERSONA_STORAGE_KEY, type Persona } from '../../lib/gateway'

// The id every pre-existing conversation already addresses (core.DefaultAgentID on the gateway) — not
// discoverable from the API, so mirrored here as the one literal this app and the gateway must agree on.
const DEFAULT_AGENT_ID = 'main'

type FormState = { display_name: string; persona: string; description: string; avatar_url: string }
const emptyForm: FormState = { display_name: '', persona: '', description: '', avatar_url: '' }

export default function SettingsPersonas() {
  const { getToken } = useAuth()
  const qc = useQueryClient()
  const confirm = useConfirm()
  const personas = useQuery({ queryKey: ['settings-personas'], queryFn: () => listPersonas(() => getToken()) })
  const [selectedId, setSelectedId] = useState(() => localStorage.getItem(SELECTED_PERSONA_STORAGE_KEY) || '')

  const select = (agentId: string) => {
    const value = agentId === DEFAULT_AGENT_ID ? '' : agentId
    localStorage.setItem(SELECTED_PERSONA_STORAGE_KEY, value)
    setSelectedId(value)
  }

  const [editing, setEditing] = useState<Persona | null>(null)
  const [creating, setCreating] = useState(false)
  const [form, setForm] = useState<FormState>(emptyForm)

  const create = useMutation({
    mutationFn: (body: FormState) =>
      createPersona(() => getToken(), {
        display_name: body.display_name,
        persona: body.persona || undefined,
        description: body.description || undefined,
        avatar_url: body.avatar_url || undefined,
      }),
    onSuccess: () => {
      toast.success('Agent created')
      setCreating(false)
      setForm(emptyForm)
      qc.invalidateQueries({ queryKey: ['settings-personas'] })
    },
    onError: (e: Error) => toast.error(e.message),
  })

  const update = useMutation({
    mutationFn: ({ agentId, patch }: { agentId: string; patch: Partial<Persona> }) => updatePersona(() => getToken(), agentId, patch),
    onSuccess: () => {
      toast.success('Agent updated')
      setEditing(null)
      qc.invalidateQueries({ queryKey: ['settings-personas'] })
    },
    onError: (e: Error) => toast.error(e.message),
  })

  const onToggleStatus = async (p: Persona) => {
    if (p.status === 'active') {
      const ok = await confirm({
        title: `Disable ${p.display_name}?`,
        body: 'Conversations already using it keep working; it stops being selectable for new ones.',
        confirmLabel: 'Disable',
        tone: 'danger',
      })
      if (!ok) return
    }
    update.mutate({ agentId: p.agent_id, patch: { status: p.status === 'active' ? 'disabled' : 'active' } })
  }

  const openEdit = (p: Persona) => {
    setForm({ display_name: p.display_name, persona: p.persona, description: p.description, avatar_url: p.avatar_url ?? '' })
    setEditing(p)
  }

  const list = personas.data ?? []

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
      title="Agents"
      description="Each agent is a standing identity — its own name, voice, and memory — that a conversation can address."
      actions={
        <Button
          size="md"
          variant="secondary"
          onClick={() => {
            setForm(emptyForm)
            setCreating(true)
          }}
        >
          New agent
        </Button>
      }
    >
      <div className="space-y-4">
        <ListCard>
          <div className="px-4 py-3">
            <p className="text-native-callout font-medium text-flat-foreground">Your agents</p>
            <p className="mt-0.5 text-sm text-flat-muted-fg">
              Choose which identity a new conversation starts with.
            </p>
          </div>
          {personas.isLoading ? (
            <p className="border-t border-flat-border px-4 py-4 text-sm text-flat-muted-fg">
              Loading…
            </p>
          ) : list.length === 0 ? (
            <EmptyState
              size="sm"
              title="No agents yet"
              body="Create one to give a conversation a different identity."
            />
          ) : (
            <table className="w-full border-t border-flat-border text-base">
              <thead>
                <tr className="border-b border-flat-border text-2xs text-flat-subtle-fg">
                  <th className="px-4 py-2 text-left font-medium">Name</th>
                  <th className="px-4 py-2 text-left font-medium">Status</th>
                  <th className="px-4 py-2 text-left font-medium">Conversations</th>
                  <th className="px-4 py-2" />
                </tr>
              </thead>
              <tbody>
                {list.map((p) => {
                  const inUse = selectedId ? selectedId === p.agent_id : p.agent_id === DEFAULT_AGENT_ID
                  return (
                    <tr key={p.agent_id} className="border-b border-flat-border last:border-0">
                      <td className="px-4 py-2 text-sm">{p.display_name}</td>
                      <td className="px-4 py-2">
                        <Badge tone={p.status === 'active' ? 'success' : 'neutral'}>
                          {p.status === 'active' ? 'Active' : 'Disabled'}
                        </Badge>
                      </td>
                      <td className="px-4 py-2">
                        {inUse ? (
                          <Badge tone="accent">In use</Badge>
                        ) : (
                          <Button
                            size="sm"
                            variant="ghost"
                            disabled={p.status !== 'active'}
                            onClick={() => select(p.agent_id)}
                          >
                            Use
                          </Button>
                        )}
                      </td>
                      <td className="px-4 py-2 text-right">
                        <Button size="sm" variant="ghost" onClick={() => openEdit(p)}>
                          Edit
                        </Button>
                        <Button
                          size="sm"
                          variant="ghost"
                          className={p.status === 'active' ? 'text-flat-danger' : undefined}
                          disabled={p.agent_id === DEFAULT_AGENT_ID && p.status === 'active'}
                          onClick={() => onToggleStatus(p)}
                        >
                          {p.status === 'active' ? 'Disable' : 'Enable'}
                        </Button>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          )}
        </ListCard>

        <Dialog
          open={creating || editing !== null}
          onOpenChange={(open) => {
            if (!open) {
              setCreating(false)
              setEditing(null)
            }
          }}
          title={editing ? `Edit ${editing.display_name}` : 'New agent'}
          size="md"
          footer={
            <>
              <Button
                variant="ghost"
                onClick={() => {
                  setCreating(false)
                  setEditing(null)
                }}
              >
                Cancel
              </Button>
              <Button
                loading={create.isPending || update.isPending}
                disabled={!form.display_name.trim()}
                onClick={() =>
                  editing
                    ? update.mutate({ agentId: editing.agent_id, patch: form })
                    : create.mutate(form)
                }
              >
                Save
              </Button>
            </>
          }
        >
          <div className="space-y-4">
            <Field label="Name" required>
              <Input
                value={form.display_name}
                onChange={(e) => setForm({ ...form, display_name: e.target.value })}
              />
            </Field>
            <Field
              label="Identity"
              hint="The identity text shown to the model — tone, role, what it’s for."
            >
              <Textarea
                rows={5}
                value={form.persona}
                onChange={(e) => setForm({ ...form, persona: e.target.value })}
              />
            </Field>
            <Field label="Description" hint="Shown in the agent list.">
              <Input
                value={form.description}
                onChange={(e) => setForm({ ...form, description: e.target.value })}
              />
            </Field>
            <Field label="Avatar URL" hint="Optional.">
              <Input
                value={form.avatar_url}
                onChange={(e) => setForm({ ...form, avatar_url: e.target.value })}
              />
            </Field>
            {editing?.agent_id === DEFAULT_AGENT_ID && (
              <p className="text-xs text-flat-muted-fg">
                This is the default agent — it can’t be disabled.
              </p>
            )}
          </div>
        </Dialog>
      </div>
    </Screen>
  )
}
