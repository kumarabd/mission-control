import type { ThreadMessageLike } from '@assistant-ui/react'

export type MessageParts = Exclude<ThreadMessageLike['content'], string>
export type MessagePart = MessageParts[number]

export function upsert(messages: ThreadMessageLike[], message: ThreadMessageLike): ThreadMessageLike[] {
  const index = messages.findIndex((item) => item.id === message.id)
  if (index === -1) return [...messages, message]
  const next = [...messages]
  next[index] = message
  return next
}

export function partsOf(message: ThreadMessageLike | undefined): MessagePart[] {
  if (!message) return []
  if (typeof message.content === 'string') {
    return message.content ? [{ type: 'text', text: message.content }] : []
  }
  return [...message.content]
}

export function textFrom(parts: MessagePart[]): string {
  return parts
    .filter((part): part is Extract<MessagePart, { type: 'text' }> => part.type === 'text')
    .map((part) => part.text)
    .join('')
}

export function replacePart(
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

export function streamMessageID(turnSeq: number): string {
  return `turn:${turnSeq}:stream`
}

/**
 * A streamed text `delta` frame applied to the thread (the non-progress branch of the hook's `delta` case).
 *
 * `rebuildingTurns` is the turns whose streamed text is being built up right now: a `replace` delta starts it (the gateway's first delta of a
 * stream, and a resume snapshot, are both replaces) and the saved assistant message ends it (`finishStreamedText`). An increment is applied only
 * while its turn is rebuilding. A saved message that already holds the whole reply must not get a late increment appended to it: a reply that
 * streams in under a second can have its last chunk reach the client just after the saved message, and appending it repeats the tail.
 */
export function applyTextDelta(
  previous: ThreadMessageLike[],
  turnSeq: number,
  frame: { text?: string; replace?: boolean },
  rebuildingTurns: Set<number>,
): ThreadMessageLike[] {
  if (frame.replace) rebuildingTurns.add(turnSeq)
  const streamID = streamMessageID(turnSeq)
  // On a cold replay the durable assistant message is emitted before its historical deltas. Reuse that first assistant message rather than
  // creating a duplicate streaming bubble. During a live turn it does not exist yet, so the ephemeral stream bubble is used and later
  // reconciled when the durable message arrives.
  const durable = previous.find(
    (message) => message.role === 'assistant' && String(message.id).startsWith(`turn:${turnSeq}:message:`),
  )
  if (durable && !rebuildingTurns.has(turnSeq)) return previous
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
}

/** The turn's saved assistant message arrived: it is final, so the streamed text is no longer being built up. */
export function finishStreamedText(rebuildingTurns: Set<number>, turnSeq: number): void {
  rebuildingTurns.delete(turnSeq)
}
