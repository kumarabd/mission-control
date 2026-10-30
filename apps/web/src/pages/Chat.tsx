import { AssistantRuntimeProvider, useAui, useAuiState } from '@assistant-ui/react'
import { useAuth } from '@clerk/clerk-react'
import { ArrowUp, MessagesSquare, Mic, Square } from 'lucide-react'
import { useCallback, useEffect, useRef, useState } from 'react'
import { useLocation, useNavigate } from 'react-router-dom'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { Button, Dialog, IconButton } from '../components/ui'
import Markdown from '../components/mission/Markdown'
import { clerkEnabled } from '../auth/clerk'
import { AgentAvatar, type AgentIdentity } from '../chat/AgentAvatar'
import { ConversationList } from '../chat/ConversationList'
import { stripToolCallText } from '../chat/toolCallText'
import { type AssistantState, type TaskProgress, useGatewayThread } from '../chat/useGatewayThread'
import { ClaudeChat } from '../chat/claude/ClaudeChat'
import { listPersonas, SELECTED_PERSONA_STORAGE_KEY } from '../lib/gateway'
import { useChatDraft } from '../lib/chatDraft'
import { useVoiceInput } from '../voice/voice-context'
import { useLiveVoice } from '../voice/useLiveVoice'
import { personal, personalKeys } from '../lib/life/personal'
import { diffWorkspace, workspaceSnapshot, type WorkspaceSnapshot, type WorkspaceUpdate } from '../lib/life/workspace'

function stateLabel(state: AssistantState): string {
  switch (state) {
    case 'thinking':
      return 'Thinking'
    case 'responding':
      return 'Responding'
    default:
      return 'Ready'
  }
}

const DEFAULT_AGENT_ID = 'main'

/** The agent this conversation is with: the chosen persona's name and picture, or the assistant's own mark. */
function useAgentIdentity(): AgentIdentity {
  const { getToken } = useAuth()
  const personas = useQuery({
    queryKey: ['settings-personas'],
    queryFn: () => listPersonas(() => getToken()),
    staleTime: 60_000,
  })
  const selected = localStorage.getItem(SELECTED_PERSONA_STORAGE_KEY) || DEFAULT_AGENT_ID
  const persona = personas.data?.find((candidate) => candidate.agent_id === selected)
  return { name: persona?.display_name || 'Assistant', avatarUrl: persona?.avatar_url ?? null }
}

function latestAssistantText(messages: readonly unknown[]): string {
  for (let index = messages.length - 1; index >= 0; index -= 1) {
    const message = messages[index] as { role?: unknown; content?: unknown } | null
    if (!message || message.role !== 'assistant') continue
    if (typeof message.content === 'string') return message.content
    if (Array.isArray(message.content)) {
      return message.content
        .map((part) => {
          if (!part || typeof part !== 'object') return ''
          const item = part as { type?: unknown; text?: unknown }
          return item.type === 'text' && typeof item.text === 'string' ? item.text : ''
        })
        .filter(Boolean)
        .join('\n')
    }
  }
  return ''
}

function LiveVoiceBar({
  voice,
}: {
  voice: ReturnType<typeof useLiveVoice>
}) {
  const label =
    voice.status === 'listening'
      ? 'Listening…'
      : voice.status === 'speaking'
        ? 'Speaking…'
        : 'Thinking…'
  const detail =
    voice.interim ||
    (voice.status === 'listening'
      ? 'Speak naturally.'
      : voice.status === 'speaking'
        ? 'Answering aloud.'
        : 'Waiting for the assistant…')
  return (
    <div className="mx-auto mb-3 w-full max-w-3xl rounded-2xl border border-flat-primary/30 bg-flat-tint px-4 py-3">
      <div className="flex items-center gap-2">
        <span
          className={`size-2 shrink-0 rounded-full bg-flat-primary ${
            voice.status === 'listening' ? 'animate-pulse motion-reduce:animate-none' : ''
          }`}
          aria-hidden
        />
        <p className="text-native-callout font-medium text-flat-foreground">{label}</p>
        <Button variant="ghost" size="sm" className="ml-auto" onClick={voice.stop}>
          End voice
        </Button>
      </div>
      <p className="mt-1 truncate text-sm text-flat-muted-fg">{detail}</p>
      {voice.error && (
        <p role="alert" className="mt-1 text-sm text-flat-danger">
          {voice.error}
        </p>
      )}
    </div>
  )
}

const KIND_LABEL: Record<WorkspaceUpdate['kind'], string> = {
  intention: 'intention',
  task: 'task',
  event: 'event',
}

function updatePath(update: WorkspaceUpdate): string {
  return update.kind === 'intention' ? '/life' : '/today'
}

/**
 * Native “Workspace updates”: the records a turn actually changed, compared
 * with the snapshot taken before it. Reads are direct so receipts never show
 * a stale cache, then the fresh records are written back into the cache.
 */
function useWorkspaceReceipts() {
  const qc = useQueryClient()
  const snapshotRef = useRef<WorkspaceSnapshot | null>(null)
  const [receipts, setReceipts] = useState<WorkspaceUpdate[]>([])

  const refresh = useCallback(async () => {
    try {
      const [tasks, events, intentions] = await Promise.all([
        personal.tasksList({ status: 'all', limit: 200 }),
        personal.eventsList({ status: 'all', limit: 200 }),
        personal.intentionsList({ limit: 100 }),
      ])
      const after = workspaceSnapshot({
        intentions: intentions.items ?? [],
        tasks: tasks.items ?? [],
        events: events.items ?? [],
      })
      const before = snapshotRef.current
      snapshotRef.current = after
      qc.setQueryData(personalKeys.tasks(), tasks)
      qc.setQueryData(personalKeys.openTasks(), tasks)
      qc.setQueryData(personalKeys.intentions(), intentions)
      void qc.invalidateQueries({ queryKey: personalKeys.day() })
      void qc.invalidateQueries({ queryKey: personalKeys.attention() })
      return { before, after }
    } catch {
      return null
    }
  }, [qc])

  useEffect(() => {
    void refresh()
  }, [refresh])

  const onTurnStart = useCallback(() => setReceipts([]), [])
  const onTurnEnd = useCallback(() => {
    void (async () => {
      const result = await refresh()
      if (!result) return
      setReceipts(result.before ? diffWorkspace(result.before, result.after) : [])
    })()
  }, [refresh])

  return { receipts, onTurnStart, onTurnEnd }
}

function TaskProgressBlock({ tasks }: { tasks: TaskProgress[] }) {
  if (!tasks.length) return null
  return (
    <section aria-label="Running tasks" className="mx-auto mt-3 flex w-full max-w-3xl flex-col gap-2">
      {tasks.map((task) => (
        <div key={task.task_id} className="rounded-2xl border border-flat-border bg-flat-surface px-4 py-3">
          <div className="flex items-center justify-between gap-3">
            <p className="text-native-callout font-medium capitalize text-flat-foreground">
              {task.skill.replaceAll('-', ' ')}
            </p>
            <p className="text-2xs text-flat-muted-fg">
              Step {task.step} of {task.total}
            </p>
          </div>
          <div
            role="progressbar"
            aria-valuemin={0}
            aria-valuemax={task.total}
            aria-valuenow={task.step}
            className="mt-2 h-1 overflow-hidden rounded-full bg-flat-border"
          >
            <div
              className="h-full rounded-full bg-flat-primary transition-[width]"
              style={{ width: `${Math.min(100, (task.step / Math.max(task.total, 1)) * 100)}%` }}
            />
          </div>
          {task.title ? <p className="mt-1 text-2xs text-flat-muted-fg">{task.title}</p> : null}
        </div>
      ))}
    </section>
  )
}

function ReceiptsBlock({ updates }: { updates: WorkspaceUpdate[] }) {
  const navigate = useNavigate()
  const aui = useAui()
  if (!updates.length) return null
  return (
    <section
      aria-label="Workspace updates"
      className="mx-auto mt-3 w-full max-w-3xl rounded-2xl border border-flat-border bg-flat-surface p-4"
    >
      <h2 className="text-native-callout font-medium text-flat-foreground">Workspace updates</h2>
      <div className="mt-2 flex flex-col divide-y divide-flat-border">
        {updates.map((update) => (
          <div key={`${update.kind}:${update.id}`} className="py-2.5 first:pt-0 last:pb-0">
            <p className="text-native-callout text-flat-foreground">{update.title}</p>
            <p className="text-2xs text-flat-muted-fg">{update.detail}</p>
            <div className="mt-1 flex flex-wrap gap-1">
              <Button
                variant="ghost"
                size="sm"
                onClick={() => navigate(updatePath(update))}
              >
                View
              </Button>
              <Button
                variant="ghost"
                size="sm"
                onClick={() =>
                  aui
                    .composer()
                    .setText(`Change my ${KIND_LABEL[update.kind]} “${update.title}”: `)
                }
              >
                Change
              </Button>
            </div>
          </div>
        ))}
      </div>
    </section>
  )
}

/** A pending ask — an `ask_user` question or a permission request — drawn as part of the thread, like iOS:
 * the agent's mark, the prompt, its options, and an inline answer field when free text is allowed. */
function AskCard({
  agent,
  prompt,
  options,
  allowFreeText,
  onSelect,
  onFreeText,
}: {
  agent: AgentIdentity
  prompt: string
  options: { id: string; label: string }[]
  allowFreeText: boolean
  onSelect: (optionId: string) => void
  onFreeText: (text: string) => void
}) {
  const [freeText, setFreeText] = useState('')
  return (
    <section
      aria-label={`${agent.name} asks`}
      className="mx-auto mt-3 w-full max-w-3xl rounded-2xl border border-flat-primary/30 bg-flat-tint p-4"
    >
      <div className="flex items-start gap-2.5">
        <AgentAvatar agent={agent} size={28} className="mt-0.5" />
        <div className="min-w-0 flex-1">
          <Markdown className="text-native-callout">{stripToolCallText(prompt)}</Markdown>
          {options.length > 0 && (
            <div className="mt-3 flex flex-col gap-2">
              {options.map((opt) => (
                <Button
                  key={opt.id}
                  variant="secondary"
                  size="touch"
                  className="w-full justify-start"
                  onClick={() => onSelect(opt.id)}
                >
                  {opt.label}
                </Button>
              ))}
            </div>
          )}
          {allowFreeText && (
            <form
              className="mt-3 flex items-center gap-2"
              onSubmit={(e) => {
                e.preventDefault()
                const text = freeText.trim()
                if (!text) return
                onFreeText(text)
                setFreeText('')
              }}
            >
              <input
                aria-label="Your answer"
                placeholder={options.length ? 'Or type your answer' : 'Your answer'}
                value={freeText}
                onChange={(e) => setFreeText(e.target.value)}
                className="h-10 min-w-0 flex-1 rounded-full border border-flat-border bg-flat-surface px-4 text-native-body text-flat-foreground outline-none placeholder:text-flat-muted-fg focus:border-flat-primary focus:ring-2 focus:ring-flat-primary/25"
              />
              <button
                type="submit"
                aria-label="Send answer"
                disabled={!freeText.trim()}
                className="grid size-10 shrink-0 place-items-center rounded-full bg-flat-primary text-flat-on-accent transition-opacity disabled:opacity-40"
              >
                <ArrowUp className="size-5" aria-hidden />
              </button>
            </form>
          )}
        </div>
      </div>
    </section>
  )
}

/** Applies a draft handed over by Today, Goals, Memory, or a receipt. */
function DraftComposer() {
  const aui = useAui()
  const location = useLocation()
  const draft = useChatDraft((state) => state.draft)
  const requestId = useChatDraft((state) => state.requestId)
  const clear = useChatDraft((state) => state.clear)
  const appliedRef = useRef(0)
  const locationApplied = useRef(false)

  useEffect(() => {
    if (!requestId || requestId === appliedRef.current) return
    appliedRef.current = requestId
    if (draft) aui.composer().setText(draft)
    queueMicrotask(clear)
  }, [aui, draft, requestId, clear])

  useEffect(() => {
    const text = (location.state as { prefill?: string } | null)?.prefill
    if (locationApplied.current || !text) return
    locationApplied.current = true
    aui.composer().setText(text)
  }, [aui, location.state])

  return null
}

// The Gateway has no auth path other than a Clerk session JWT — useGatewayThread
// calls Clerk's useAuth() internally, which throws if no <ClerkProvider> is
// mounted. So this must never render when Clerk isn't configured.
export default function Chat() {
  if (!clerkEnabled) {
    return (
      <div className="flex h-full items-center justify-center p-6 text-center text-base text-flat-muted-fg">
        Chat needs Clerk sign-in, which isn&apos;t configured in this build.
      </div>
    )
  }
  return <ChatThread />
}

function ChatThread() {
  const { receipts, onTurnStart, onTurnEnd } = useWorkspaceReceipts()
  const gateway = useGatewayThread({ onTurnStart, onTurnEnd })

  return (
    <AssistantRuntimeProvider runtime={gateway.runtime}>
      <DraftComposer />
      <ChatSurface gateway={gateway} receipts={receipts} />
    </AssistantRuntimeProvider>
  )
}

function ChatSurface({
  gateway,
  receipts,
}: {
  gateway: ReturnType<typeof useGatewayThread>
  receipts: WorkspaceUpdate[]
}) {
  const {
    pendingInput,
    tasks,
    respond,
    connectionState,
    connectionError,
    assistantState,
    sessions,
    sessionsLoading,
    currentSessionId,
    forkSession,
    toggleSessionExpanded,
  } = gateway
  const aui = useAui()
  const messages = useAuiState((state) => state.thread.messages)
  const isRunning = useAuiState((state) => state.thread.isRunning)
  const { enabled: voiceEnabled } = useVoiceInput()
  const [conversationsOpen, setConversationsOpen] = useState(false)
  const previousRunning = useRef(isRunning)
  const connected = connectionState === 'live'
  const activeSession = sessions.find((session) => session.session_id === currentSessionId)
  const agent = useAgentIdentity()

  const handleUtterance = useCallback(
    (text: string): boolean => {
      if (pendingInput) {
        const normalized = text.toLowerCase().trim()
        const option = pendingInput.options.find((candidate) => {
          const label = candidate.label.toLowerCase()
          return label.includes(normalized) || normalized.includes(label)
        })
        if (option) {
          void respond({ selectedOptionId: option.id })
          return true
        }
        if (pendingInput.allow_free_text) {
          void respond({ freeText: text })
          return true
        }
        return false
      }
      if (isRunning) return false
      aui.thread.append({ role: 'user', content: [{ type: 'text', text }] })
      return true
    },
    [aui, isRunning, pendingInput, respond],
  )

  const voice = useLiveVoice(handleUtterance)
  const noteVoiceDone = voice.noteAssistantDone
  const voiceActive = voice.active
  const stopVoice = voice.stop

  useEffect(() => {
    if (previousRunning.current && !isRunning && voiceActive) {
      noteVoiceDone(stripToolCallText(latestAssistantText(messages)))
    }
    previousRunning.current = isRunning
  }, [isRunning, messages, noteVoiceDone, voiceActive])

  useEffect(() => {
    if (!voiceEnabled && voiceActive) stopVoice()
  }, [voiceEnabled, voiceActive, stopVoice])

  return (
    <>
      <div className="flex h-full min-h-0 bg-flat-background">
        <aside className="hidden w-64 shrink-0 border-r border-flat-border bg-flat-surface md:flex md:flex-col">
          <ConversationList
            isLoading={sessionsLoading}
            onFork={forkSession}
            onToggleExpand={toggleSessionExpanded}
            className="flex-1"
          />
        </aside>

        <div className="flex min-w-0 flex-1 flex-col">
          <div className="flex h-14 shrink-0 items-center gap-2 border-b border-flat-border bg-flat-surface px-3 sm:gap-2.5 sm:px-5">
            <IconButton
              label="Conversations"
              size="lg"
              className="md:hidden"
              onClick={() => setConversationsOpen(true)}
            >
              <MessagesSquare aria-hidden />
            </IconButton>
            <div className="flex min-w-0 flex-1 items-center gap-2.5">
              <AgentAvatar agent={agent} size={30} />
              <div className="min-w-0">
                <p className="truncate text-native-callout font-medium text-flat-foreground">{agent.name}</p>
                <p className="truncate text-2xs text-flat-muted-fg">{activeSession?.title || 'Chat'}</p>
              </div>
            </div>
            {voiceEnabled && voice.supported && (
              <IconButton
                label={voice.active ? 'End live voice' : 'Start live voice'}
                size="lg"
                variant={voice.active ? 'outline' : 'ghost'}
                className="focus:outline-none"
                onClick={voice.active ? voice.stop : voice.start}
              >
                {voice.active ? <Square className="size-4" aria-hidden /> : <Mic aria-hidden />}
              </IconButton>
            )}
            <span
              className={`size-1.5 rounded-full ${connected ? 'bg-flat-success' : 'bg-flat-warning'}`}
              aria-hidden
            />
            <span className="shrink-0 rounded-full border border-flat-border px-2.5 py-0.5 font-mono text-2xs text-flat-muted-fg">
              {stateLabel(assistantState)}
            </span>
            {!connected && (
              <span className="hidden text-2xs text-flat-muted-fg sm:inline">
                {connectionState === 'connecting'
                  ? 'connecting'
                  : connectionState === 'offline'
                    ? 'offline'
                    : 'reconnecting'}
              </span>
            )}
            {connectionError && (
              <span className="ml-auto hidden truncate text-2xs text-flat-danger sm:inline">
                {connectionError}
              </span>
            )}
          </div>
          <div className="min-h-0 flex-1">
            <ClaudeChat
              agent={agent}
              transcriptSlot={
                <>
                  <ReceiptsBlock updates={receipts} />
                  <TaskProgressBlock tasks={tasks} />
                  {pendingInput ? (
                    <AskCard
                      agent={agent}
                      prompt={pendingInput.prompt}
                      options={pendingInput.options}
                      allowFreeText={pendingInput.allow_free_text}
                      onSelect={(optionId) => void respond({ selectedOptionId: optionId })}
                      onFreeText={(text) => void respond({ freeText: text })}
                    />
                  ) : null}
                </>
              }
              footerSlot={voice.active ? <LiveVoiceBar voice={voice} /> : null}
            />
          </div>
        </div>
      </div>

      <Dialog
        open={conversationsOpen}
        onOpenChange={setConversationsOpen}
        title="Conversations"
        placement="responsive"
      >
        <ConversationList
          isLoading={sessionsLoading}
          onNavigate={() => setConversationsOpen(false)}
          onFork={(sessionId) => {
            forkSession(sessionId)
            setConversationsOpen(false)
          }}
          onToggleExpand={toggleSessionExpanded}
          showHeading={false}
          className="h-[60vh]"
        />
      </Dialog>
    </>
  )
}
