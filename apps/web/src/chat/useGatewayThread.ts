import { useAuth } from '@clerk/clerk-react'
import type { AppendMessage, ThreadMessageLike } from '@assistant-ui/react'
import { useExternalStoreRuntime } from '@assistant-ui/react'
import { WebSpeechDictationAdapter } from '@assistant-ui/react'
import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import {
  cancelTurn,
  listSessions,
  pollTurns,
  realtimeGatewayUrl,
  respondToInput,
  sendMessage,
  SELECTED_PERSONA_STORAGE_KEY,
  type PendingInput,
  type PolledToolCall,
  type PolledTurn,
  type SessionSummary,
} from '../lib/gateway'
import { useVoiceInput } from '../voice/voice-context'

const PENDING_PREFIX = 'pending:'
const MAIN_SESSION_ID = 'main'
const FALLBACK_POLL_INTERVAL_MS = 3000

type ConnectionState = 'connecting' | 'live' | 'reconnecting' | 'offline'
export type AssistantState = 'ready' | 'thinking' | 'responding'
export type RespondAnswer = { selectedOptionId?: string; freeText?: string }

/** A skill task's place in its steps. It belongs to the task, not to a turn: the turn that started it has ended. */
export type TaskProgress = {
  task_id: string
  skill: string
  step: number
  total: number
  title: string
  /** "running" until the task ends, then its outcome. */
  state: string
}

type GatewayFrame = {
  type: string
  task_id?: string
  skill?: string
  step?: number
  total?: number
  title?: string
  state?: string
  turn_seq?: number
  through_turn_seq?: number
  seq?: number
  message_seq?: number
  status?: 'pending' | 'ok' | 'error' | 'completed' | 'cancelled' | 'failed'
  role?: 'user' | 'assistant'
  content?: string
  text?: string
  replace?: boolean
  progress?: boolean
  client_msg_id?: string
  request_id?: string
  kind?: string
  prompt?: string
  options?: { id: string; label: string }[]
  allow_free_text?: boolean
  message?: string
  tool_call_id?: string
  tool_name?: string
  arguments?: unknown
  result?: unknown
  partial_output?: string
  reason?: string
  started_at?: string
  completed_at?: string
}

type MessageParts = Exclude<ThreadMessageLike['content'], string>
type MessagePart = MessageParts[number]
type ToolArguments = Extract<MessagePart, { type: 'tool-call' }>['args']

function textOf(message: AppendMessage): string {
  return message.content
    .filter((part): part is { type: 'text'; text: string } => part.type === 'text')
    .map((part) => part.text)
    .join('')
}

function upsert(messages: ThreadMessageLike[], message: ThreadMessageLike): ThreadMessageLike[] {
  const index = messages.findIndex((item) => item.id === message.id)
  if (index === -1) return [...messages, message]
  const next = [...messages]
  next[index] = message
  return next
}

function partsOf(message: ThreadMessageLike | undefined): MessagePart[] {
  if (!message) return []
  if (typeof message.content === 'string') {
    return message.content ? [{ type: 'text', text: message.content }] : []
  }
  return [...message.content]
}

function textFrom(parts: MessagePart[]): string {
  return parts
    .filter((part): part is Extract<MessagePart, { type: 'text' }> => part.type === 'text')
    .map((part) => part.text)
    .join('')
}

function replacePart(
  parts: MessagePart[],
  type: 'text' | 'reasoning',
  replacement: Extract<MessagePart, { type: typeof type }>,
): MessagePart[] {
  const index = parts.findIndex((part) => part.type === type)
  if (index === -1) return [...parts, replacement]
  const next = [...parts]
  next[index] = replacement
  return next
}

function messageID(turnSeq: number, seq: number): string {
  return `turn:${turnSeq}:message:${seq}`
}

function streamMessageID(turnSeq: number): string {
  return `turn:${turnSeq}:stream`
}

function failureMessage(error: unknown, fallback: string): string {
  return error instanceof Error && error.message.trim() ? error.message : fallback
}

function asArguments(value: unknown): ToolArguments {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
    ? (value as ToolArguments)
    : {}
}

function toolPartFromPoll(tool: PolledToolCall): MessagePart {
  const startedAt = tool.started_at ? Date.parse(tool.started_at) : Date.now()
  const completedAt = tool.completed_at ? Date.parse(tool.completed_at) : undefined
  return {
    type: 'tool-call',
    toolCallId: tool.tool_call_id,
    toolName: tool.tool_name,
    args: asArguments(tool.arguments),
    ...(tool.result !== undefined ? { result: tool.result } : {}),
    ...(tool.status === 'error' ? { isError: true } : {}),
    providerMetadata: { gateway: { status: tool.status } },
    timing: {
      startedAt: Number.isNaN(startedAt) ? Date.now() : startedAt,
      ...(completedAt != null && !Number.isNaN(completedAt) ? { completedAt } : {}),
    },
  }
}

function turnToMessages(turn: PolledTurn): ThreadMessageLike[] {
  const result: ThreadMessageLike[] = []
  if (turn.user_content) {
    result.push({ id: messageID(turn.turn_seq, 0), role: 'user', content: turn.user_content })
  }
  const toolParts = (turn.tool_calls ?? [])
    .slice()
    .sort((a, b) => a.message_seq - b.message_seq)
    .map(toolPartFromPoll)
  if (turn.content || toolParts.length > 0) {
    result.push({
      id: `turn:${turn.turn_seq}:poll-assistant`,
      role: 'assistant',
      content: [...toolParts, ...(turn.content ? ([{ type: 'text', text: turn.content }] as MessagePart[]) : [])],
      status: { type: 'complete', reason: 'stop' },
    })
  }
  return result
}

export function useGatewayThread(
  options: { onTurnStart?: () => void; onTurnEnd?: () => void } = {},
) {
  const { onTurnStart, onTurnEnd } = options
  const { getToken } = useAuth()
  const { enabled: voiceEnabled, supported: voiceSupported } = useVoiceInput()
  const tokenGetter = useCallback(() => getToken(), [getToken])
  const dictationAdapter = useMemo(
    () => (voiceEnabled && voiceSupported ? new WebSpeechDictationAdapter() : undefined),
    [voiceEnabled, voiceSupported],
  )

  const [messages, setMessages] = useState<ThreadMessageLike[]>([])
  const [pendingInput, setPendingInput] = useState<PendingInput | null>(null)
  const [tasks, setTasks] = useState<TaskProgress[]>([])
  const [isRunning, setIsRunning] = useState(false)
  const [connectionState, setConnectionState] = useState<ConnectionState>('connecting')
  const [connectionError, setConnectionError] = useState<string | null>(null)
  const [assistantState, setAssistantState] = useState<AssistantState>('ready')
  const [sessions, setSessions] = useState<SessionSummary[]>([])
  const [sessionsLoading, setSessionsLoading] = useState(true)
  const [explicitSessionId, setExplicitSessionId] = useState<string | undefined>(undefined)
  const [expandedSessions, setExpandedSessions] = useState<Set<string>>(new Set())
  const [completedTurns, setCompletedTurns] = useState(0)

  const socketRef = useRef<WebSocket | null>(null)
  const reconnectTimerRef = useRef<number | null>(null)
  const throughTurnSeqRef = useRef(0)
  const hydratedSessionRef = useRef(new Set<string>())
  const awaitingTurnRef = useRef(false)

  const notifyTurnStart = useCallback(() => {
    awaitingTurnRef.current = true
    onTurnStart?.()
  }, [onTurnStart])

  const notifyTurnEnd = useCallback(() => {
    if (!awaitingTurnRef.current) return
    awaitingTurnRef.current = false
    setCompletedTurns((count) => count + 1)
    onTurnEnd?.()
  }, [onTurnEnd])

  // "main" is the stable sentinel for the default conversation, not merely the first root: a genuinely new session
  // is also a root now, and must never take main's place on reload.
  const currentSessionId = explicitSessionId ?? MAIN_SESSION_ID
  const activeSessionId = currentSessionId
  const activeParentSessionId = sessions.find((session) => session.session_id === activeSessionId)?.parent_session_id

  const { visibleSessions, threadDepth, threadChildCount, threadExpanded } = useMemo(() => {
    const main: SessionSummary = {
      session_id: MAIN_SESSION_ID,
      parent_session_id: null,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
      title: 'Main conversation',
      preview: '',
      is_running: false,
    }
    const hasMain = sessions.some((session) => session.session_id === MAIN_SESSION_ID)
    const all = hasMain ? sessions : [main, ...sessions]
    const byID = new Map(all.map((session) => [session.session_id, session] as const))
    const children = new Map<string, SessionSummary[]>()
    const roots: SessionSummary[] = []
    for (const session of all) {
      const parent = session.parent_session_id
      if (parent && parent !== session.session_id && byID.has(parent)) {
        const siblings = children.get(parent) ?? []
        siblings.push(session)
        children.set(parent, siblings)
      } else {
        roots.push(session)
      }
    }
    // Folders read latest-first at every level; forks stay nested under their parent.
    const latestFirst = (a: SessionSummary, b: SessionSummary) =>
      Date.parse(b.updated_at) - Date.parse(a.updated_at)
    roots.sort(latestFirst)
    for (const siblings of children.values()) siblings.sort(latestFirst)
    // The synthetic main has no gateway timestamp until its first message, so it
    // stays pinned as the default conversation.
    if (!hasMain) {
      const index = roots.findIndex((session) => session.session_id === MAIN_SESSION_ID)
      if (index > 0) roots.unshift(...roots.splice(index, 1))
    }
    const list: SessionSummary[] = []
    const depth = new Map<string, number>()
    const seen = new Set<string>()
    const visit = (session: SessionSummary, level: number) => {
      if (seen.has(session.session_id)) return
      seen.add(session.session_id)
      list.push(session)
      depth.set(session.session_id, level)
      for (const child of children.get(session.session_id) ?? []) visit(child, level + 1)
    }
    roots.forEach((root) => visit(root, 0))
    for (const session of all) visit(session, 0) // a malformed parent cycle still gets listed, once
    // A fork is hidden until every ancestor folder is expanded.
    const isOpen = (session: SessionSummary) => {
      let parent = session.parent_session_id
      let guard = 0
      while (parent && guard < 8) {
        if (!expandedSessions.has(parent)) return false
        const ancestor = byID.get(parent)
        if (!ancestor) break
        parent = ancestor.parent_session_id
        guard += 1
      }
      return true
    }
    const childCount = new Map(all.map((session) => [session.session_id, children.get(session.session_id)?.length ?? 0] as const))
    return {
      visibleSessions: list.filter(isOpen),
      threadDepth: depth,
      threadChildCount: childCount,
      threadExpanded: expandedSessions,
    }
  }, [expandedSessions, sessions])

  const refreshSessions = useCallback(async () => {
    try {
      const fetched = await listSessions(tokenGetter)
      setSessions((previous) => {
        const byID = new Map(fetched.map((session) => [session.session_id, session] as const))
        for (const session of previous) {
          if (!byID.has(session.session_id)) byID.set(session.session_id, session)
        }
        return Array.from(byID.values())
      })
    } catch {
      // Session navigation is supplementary; a live conversation remains
      // usable when this independent read is temporarily unavailable.
    } finally {
      setSessionsLoading(false)
    }
  }, [tokenGetter])

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- asynchronous fetch-on-mount; state changes only after the request resolves
    void refreshSessions()
  }, [refreshSessions])

  const applyFrame = useCallback(
    (frame: GatewayFrame) => {
      const turnSeq = frame.turn_seq
      switch (frame.type) {
        case 'turn_start':
          setIsRunning(true)
          setAssistantState('thinking')
          return
        case 'message': {
          if (turnSeq == null || frame.seq == null || !frame.role) return
          const role = frame.role
          const id = messageID(turnSeq, frame.seq)
          setMessages((previous) => {
            const withoutEchoedPending =
              role === 'user' && frame.client_msg_id
                ? previous.filter((item) => item.id !== `${PENDING_PREFIX}${frame.client_msg_id}`)
                : previous
            if (role === 'user') {
              return upsert(withoutEchoedPending, { id, role, content: frame.content ?? '' })
            }

            const streamID = streamMessageID(turnSeq)
            const streamed = withoutEchoedPending.find((message) => message.id === streamID)
            const existing = withoutEchoedPending.find((message) => message.id === id)
            const activityParts = partsOf(streamed).filter((part) => part.type === 'reasoning')
            const existingNonText = partsOf(existing).filter((part) => part.type !== 'text')
            const content: MessagePart[] = [
              ...activityParts,
              ...existingNonText,
              ...((frame.content ?? '').trim()
                ? ([{ type: 'text', text: frame.content ?? '' }] as MessagePart[])
                : []),
            ]
            return upsert(
              withoutEchoedPending.filter((message) => message.id !== streamID),
              { id, role: 'assistant', content, status: { type: 'running' } },
            )
          })
          return
        }
        case 'tool_call': {
          if (
            turnSeq == null ||
            frame.message_seq == null ||
            !frame.tool_call_id ||
            !frame.tool_name ||
            !frame.status
          ) {
            return
          }
          const id = messageID(turnSeq, frame.message_seq)
          const polledID = `turn:${turnSeq}:poll-assistant`
          const startedAt = frame.started_at ? Date.parse(frame.started_at) : Date.now()
          const completedAt = frame.completed_at ? Date.parse(frame.completed_at) : undefined
          const toolPart: MessagePart = {
            type: 'tool-call',
            toolCallId: frame.tool_call_id,
            toolName: frame.tool_name,
            args: asArguments(frame.arguments),
            ...(frame.status !== 'pending' && frame.result !== undefined ? { result: frame.result } : {}),
            ...(frame.status === 'error' ? { isError: true } : {}),
            providerMetadata: {
              gateway: {
                status: frame.status,
                partialOutput: frame.partial_output ?? '',
                reason: frame.reason ?? '',
              },
            },
            timing: {
              startedAt: Number.isNaN(startedAt) ? Date.now() : startedAt,
              ...(completedAt != null && !Number.isNaN(completedAt) ? { completedAt } : {}),
            },
          }
          setMessages((previous) => {
            const existing = previous.find((message) => message.id === id)
              ?? previous.find((message) => message.id === polledID)
            const parts = partsOf(existing)
            const partIndex = parts.findIndex(
              (part) => part.type === 'tool-call' && part.toolCallId === frame.tool_call_id,
            )
            const nextParts = [...parts]
            if (partIndex === -1) nextParts.push(toolPart)
            else nextParts[partIndex] = toolPart
            return upsert(previous, {
              id: existing?.id ?? id,
              role: 'assistant',
              content: nextParts,
              status: existing?.status ?? { type: 'running' },
            })
          })
          return
        }
        case 'delta': {
          if (turnSeq == null) return
          const streamID = streamMessageID(turnSeq)
          if (frame.progress) {
            setAssistantState('thinking')
            setMessages((previous) => {
              const existing = previous.find((message) => message.id === streamID)
              const parts = partsOf(existing)
              const current = parts.find(
                (part): part is Extract<MessagePart, { type: 'reasoning' }> => part.type === 'reasoning',
              )
              const text = frame.replace ? (frame.text ?? '') : `${current?.text ?? ''}${frame.text ?? ''}`
              return upsert(previous, {
                id: streamID,
                role: 'assistant',
                content: replacePart(parts, 'reasoning', {
                  type: 'reasoning',
                  text,
                  status: { type: 'running' },
                }),
                status: { type: 'running' },
              })
            })
            return
          }
          setAssistantState('responding')
          setMessages((previous) => {
            // On a cold replay the durable assistant message is emitted before
            // its historical deltas. Reuse that first assistant message rather
            // than creating a duplicate streaming bubble. During a live turn
            // it does not exist yet, so the ephemeral stream bubble is used and
            // later reconciled when the durable message arrives.
            const durable = previous.find(
              (message) =>
                message.role === 'assistant' &&
                String(message.id).startsWith(`turn:${turnSeq}:message:`),
            )
            const id = durable?.id ?? streamID
            const existing = previous.find((message) => message.id === id)
            const parts = partsOf(existing)
            const nextContent = frame.replace ? (frame.text ?? '') : `${textFrom(parts)}${frame.text ?? ''}`
            return upsert(previous, {
              id,
              role: 'assistant',
              content: replacePart(parts, 'text', { type: 'text', text: nextContent }),
              status: { type: 'running' },
            })
          })
          return
        }
        case 'task_progress': {
          const { task_id, skill, step, total, state } = frame
          if (!task_id || !skill || step == null || total == null || !state) return
          const progress: TaskProgress = { task_id, skill, step, total, title: frame.title ?? '', state }
          setTasks((previous) => {
            const others = previous.filter((task) => task.task_id !== task_id)
            return state === 'running' ? [...others, progress] : others
          })
          return
        }
        case 'ask_user':
          if (!frame.request_id || !frame.prompt) return
          setPendingInput({
            request_id: frame.request_id,
            kind: frame.kind ?? '',
            prompt: frame.prompt,
            options: frame.options ?? [],
            allow_free_text: Boolean(frame.allow_free_text),
          })
          setIsRunning(false)
          setAssistantState('ready')
          return
        case 'turn_end':
          if (turnSeq != null) throughTurnSeqRef.current = Math.max(throughTurnSeqRef.current, turnSeq)
          if (turnSeq != null) {
            const prefix = `turn:${turnSeq}:`
            setMessages((previous) =>
              previous.map((message) => {
                if (message.role !== 'assistant' || !String(message.id).startsWith(prefix)) return message
                return {
                  ...message,
                  status:
                    frame.status === 'completed'
                      ? ({ type: 'complete', reason: 'stop' } as const)
                      : ({
                          type: 'incomplete',
                          reason: frame.status === 'cancelled' ? 'cancelled' : 'error',
                        } as const),
                }
              }),
            )
          }
          setIsRunning(false)
          setAssistantState('ready')
          void refreshSessions()
          notifyTurnEnd()
          return
        case 'resumed':
          if (frame.through_turn_seq != null) {
            throughTurnSeqRef.current = Math.max(throughTurnSeqRef.current, frame.through_turn_seq)
          }
          setConnectionState('live')
          setConnectionError(null)
          return
        case 'error':
          setConnectionError(frame.message ?? 'realtime connection failed')
          return
        default:
          return
      }
    },
    [refreshSessions, notifyTurnEnd],
  )

  useEffect(() => {
    let disposed = false
    let attempts = 0

    const scheduleReconnect = () => {
      if (disposed || reconnectTimerRef.current != null) return
      setConnectionState('reconnecting')
      attempts += 1
      const delay = Math.min(1000 * 2 ** Math.min(attempts, 3), 8000)
      reconnectTimerRef.current = window.setTimeout(() => {
        reconnectTimerRef.current = null
        void connect()
      }, delay)
    }

    const connect = async () => {
      if (disposed) return
      setConnectionState(attempts === 0 ? 'connecting' : 'reconnecting')
      let token: string | null
      try {
        token = await tokenGetter()
      } catch (error) {
        setConnectionError(failureMessage(error, 'could not verify your session'))
        scheduleReconnect()
        return
      }
      if (disposed) return
      if (!token) {
        setConnectionState('offline')
        setConnectionError('not signed in')
        return
      }

      let socket: WebSocket
      try {
        socket = new WebSocket(realtimeGatewayUrl(token))
      } catch (error) {
        setConnectionError(failureMessage(error, 'could not start the realtime connection'))
        scheduleReconnect()
        return
      }
      socketRef.current = socket
      socket.onopen = () => {
        if (disposed) return
        attempts = 0
        socket.send(
          JSON.stringify({
            type: 'auth',
            token,
            session_id: activeSessionId,
            parent_session_id: activeParentSessionId ?? undefined,
            after_turn_seq: throughTurnSeqRef.current,
            capabilities: ['tool_calls'],
            agent_id: localStorage.getItem(SELECTED_PERSONA_STORAGE_KEY) || undefined,
          }),
        )
      }
      socket.onmessage = (event) => {
        if (disposed || socketRef.current !== socket) return
        try {
          const frame = JSON.parse(String(event.data)) as GatewayFrame
          if (frame.type === 'resumed') attempts = 0
          applyFrame(frame)
        } catch {
          setConnectionError('received an invalid realtime event')
        }
      }
      socket.onerror = () => {
        if (!disposed && socketRef.current === socket) setConnectionError('connection interrupted')
      }
      socket.onclose = () => {
        if (socketRef.current === socket) socketRef.current = null
        if (disposed) return
        scheduleReconnect()
      }
    }

    void connect()
    return () => {
      disposed = true
      if (reconnectTimerRef.current != null) window.clearTimeout(reconnectTimerRef.current)
      reconnectTimerRef.current = null
      socketRef.current?.close()
      socketRef.current = null
    }
  }, [activeParentSessionId, activeSessionId, applyFrame, tokenGetter])

  // The socket is the low-latency path; polling remains the durable recovery
  // path whenever realtime is unavailable. This also keeps the page useful
  // against an older gateway deployment that has not exposed /web/ws yet.
  useEffect(() => {
    let disposed = false
    let inFlight = false
    const applyPolledTurns = (result: Awaited<ReturnType<typeof pollTurns>>) => {
      if (result.turns.length > 0) {
        const priorThrough = throughTurnSeqRef.current
        setMessages((previous) => {
          let next = previous.filter((message) => !String(message.id).startsWith(PENDING_PREFIX))
          for (const turn of result.turns) {
            for (const message of turnToMessages(turn)) next = upsert(next, message)
          }
          return next
        })
        throughTurnSeqRef.current = Math.max(
          throughTurnSeqRef.current,
          ...result.turns.map((turn) => turn.turn_seq),
        )
        if (result.turns.some((turn) => turn.turn_seq > priorThrough)) {
          setIsRunning(false)
          setAssistantState('ready')
          notifyTurnEnd()
        }
      }
      setPendingInput(result.pending_input)
    }
    const poll = async (sinceTurnSeq = throughTurnSeqRef.current) => {
      if (disposed || inFlight) return
      inFlight = true
      try {
        const result = await pollTurns(tokenGetter, sinceTurnSeq, activeSessionId)
        if (disposed) return
        applyPolledTurns(result)
        if (sinceTurnSeq === 0) hydratedSessionRef.current.add(activeSessionId)
      } catch {
        // Connection errors are surfaced by the realtime path. Polling keeps
        // retrying quietly because it is the fallback, not a second status.
      } finally {
        inFlight = false
      }
    }

    // A completed WebSocket can become live before the selected session is
    // known. Hydrate its durable turn history once regardless of socket state.
    if (!hydratedSessionRef.current.has(activeSessionId)) void poll(0)
    if (connectionState === 'live') return () => { disposed = true }
    const timer = window.setInterval(() => void poll(), FALLBACK_POLL_INTERVAL_MS)
    return () => {
      disposed = true
      window.clearInterval(timer)
    }
  }, [activeSessionId, connectionState, tokenGetter, notifyTurnEnd])

  const onNew = useCallback(
    async (message: AppendMessage) => {
      const text = textOf(message).trim()
      if (!text) return
      notifyTurnStart()

      const clientMessageId = crypto.randomUUID()
      setMessages((previous) => [
        ...previous,
        { id: `${PENDING_PREFIX}${clientMessageId}`, role: 'user', content: text },
      ])
      setIsRunning(true)
      setAssistantState('thinking')

      const socket = socketRef.current
      if (socket?.readyState === WebSocket.OPEN) {
        try {
          socket.send(JSON.stringify({ type: 'message', client_msg_id: clientMessageId, text, mode: 'text' }))
          return
        } catch {
          // The socket can close between readyState and send. Use the durable
          // HTTP path instead of leaving the optimistic message stranded.
        }
      }

      try {
        await sendMessage(
          tokenGetter,
          text,
          clientMessageId,
          activeSessionId,
          activeParentSessionId ?? undefined,
          localStorage.getItem(SELECTED_PERSONA_STORAGE_KEY) ?? undefined,
        )
        void refreshSessions()
      } catch (error) {
        setIsRunning(false)
        setAssistantState('ready')
        setConnectionError(failureMessage(error, 'could not send your message'))
      }
    },
    [activeParentSessionId, activeSessionId, refreshSessions, tokenGetter, notifyTurnStart],
  )

  const respond = useCallback(
    async (answer: RespondAnswer) => {
      if (!pendingInput) return
      notifyTurnStart()
      const socket = socketRef.current
      try {
        if (socket?.readyState === WebSocket.OPEN) {
          socket.send(
            JSON.stringify({
              type: 'answer',
              request_id: pendingInput.request_id,
              selected_option_id: answer.selectedOptionId,
              free_text: answer.freeText,
            }),
          )
        } else {
          await respondToInput(tokenGetter, pendingInput.request_id, answer, activeSessionId)
        }
      } catch (error) {
        setConnectionError(failureMessage(error, 'could not send your answer'))
        return
      }
      setPendingInput(null)
      setIsRunning(true)
      setAssistantState('thinking')
    },
    [activeSessionId, pendingInput, tokenGetter, notifyTurnStart],
  )

  const cancel = useCallback(async () => {
    const socket = socketRef.current
    try {
      if (socket?.readyState === WebSocket.OPEN) {
        socket.send(JSON.stringify({ type: 'cancel' }))
        return
      }
      await cancelTurn(tokenGetter, activeSessionId)
    } catch (error) {
      setConnectionError(failureMessage(error, 'could not stop the response'))
    }
  }, [activeSessionId, tokenGetter])

  const switchToSession = useCallback((sessionId: string) => {
    setExplicitSessionId(sessionId)
    setMessages([])
    setPendingInput(null)
    setTasks([])
    setIsRunning(false)
    setAssistantState('ready')
    throughTurnSeqRef.current = 0
    awaitingTurnRef.current = false
  }, [])

  /// Opens a new local conversation with the given parent: null is a genuinely fresh root (no inherited context),
  /// a session id forks that conversation (the gateway copies its context at genesis). The list nests forks under their
  /// parent.
  const openSession = useCallback((parentSessionId: string | null) => {
    const newSessionId = crypto.randomUUID()
    const now = new Date().toISOString()
    setSessions((previous) => [
      ...previous,
      {
        session_id: newSessionId,
        parent_session_id: parentSessionId,
        created_at: now,
        updated_at: now,
        title: parentSessionId ? 'Forked conversation' : 'New conversation',
        preview: '',
        is_running: false,
      },
    ])
    if (parentSessionId) {
      setExpandedSessions((previous) => {
        if (previous.has(parentSessionId)) return previous
        const next = new Set(previous)
        next.add(parentSessionId)
        return next
      })
    }
    setExplicitSessionId(newSessionId)
    setMessages([])
    setPendingInput(null)
    setTasks([])
    setIsRunning(false)
    setAssistantState('ready')
    throughTurnSeqRef.current = 0
    awaitingTurnRef.current = false
  }, [])

  const startSession = useCallback(() => openSession(null), [openSession])
  const forkSession = useCallback((parentSessionId: string) => openSession(parentSessionId), [openSession])
  const toggleSessionExpanded = useCallback((sessionId: string) => {
    setExpandedSessions((previous) => {
      const next = new Set(previous)
      if (next.has(sessionId)) next.delete(sessionId)
      else next.add(sessionId)
      return next
    })
  }, [])

  // assistant-ui's external thread-list adapter is intentionally isolated to
  // this boundary; the package still marks the API as evolving. Gateway
  // session IDs remain the source of truth and never leak into presentation
  // components directly.
  const threadList = useMemo(
    () => ({
      threadId: activeSessionId,
      isLoading: sessionsLoading,
      threads: visibleSessions.map((session) => ({
        status: 'regular' as const,
        id: session.session_id,
        title: session.title,
        custom: {
          updatedAt: session.updated_at,
          isRunning: session.session_id === activeSessionId ? isRunning : session.is_running,
          isFork: session.parent_session_id != null,
          depth: threadDepth.get(session.session_id) ?? 0,
          childCount: threadChildCount.get(session.session_id) ?? 0,
          expanded: threadExpanded.has(session.session_id),
        },
      })),
      onSwitchToThread: switchToSession,
      onSwitchToNewThread: startSession,
    }),
    [
      activeSessionId,
      isRunning,
      sessionsLoading,
      startSession,
      switchToSession,
      threadChildCount,
      threadDepth,
      threadExpanded,
      visibleSessions,
    ],
  )

  // A message sent while a turn runs goes straight to the gateway: the harness routes it (to a running task, or a new
  // request), so nothing is held back client-side.
  const queue = useMemo(
    () => ({
      items: [],
      steerItems: [],
      enqueue: (message: AppendMessage) => void onNew(message),
      steer: (message: AppendMessage) => void onNew(message),
      move: () => {},
      edit: () => {},
      remove: () => {},
    }),
    [onNew],
  )

  const runtime = useExternalStoreRuntime<ThreadMessageLike>({
    messages,
    isRunning,
    onNew,
    onCancel: cancel,
    convertMessage: (message) => message,
    queue,
    adapters: { threadList, dictation: dictationAdapter },
  })

  // Voice input is an optional composer modality. Disabling it only ends the
  // microphone session; the composer text, selected session, and chat stream
  // are deliberately left intact.
  useEffect(() => {
    if (!voiceEnabled) runtime.thread.composer.stopDictation()
  }, [runtime, voiceEnabled])

  return {
    runtime,
    pendingInput,
    tasks,
    respond,
    connectionState,
    connectionError,
    assistantState,
    sessions,
    sessionsLoading,
    currentSessionId: activeSessionId,
    mainSessionId: MAIN_SESSION_ID,
    completedTurns,
    switchToSession,
    startSession,
    forkSession,
    toggleSessionExpanded,
  }
}
