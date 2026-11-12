import type { ThreadMessageLike } from '@assistant-ui/react'
import { describe, expect, it } from 'vitest'
import { applyTextDelta, finishStreamedText, streamMessageID, textFrom, partsOf } from './threadMessages'

const FULL = 'The user is doing well and has been actively planning a relaxed weekend trip. They are currently in California.'
const user: ThreadMessageLike = { id: 'turn:1:message:0', role: 'user', content: 'Hey hows it going?' }
const durable = (text: string): ThreadMessageLike => ({
  id: 'turn:1:message:2', role: 'assistant', content: [{ type: 'text', text }], status: { type: 'running' },
})
const textOfAssistant = (messages: ThreadMessageLike[]) =>
  messages.filter((m) => m.role === 'assistant').map((m) => textFrom(partsOf(m)))

describe('applyTextDelta', () => {
  it('streams into one bubble before the saved message exists', () => {
    // The gateway's first delta is a replace (empty last buffer), the rest are increments.
    const rebuilding = new Set<number>()
    let thread: ThreadMessageLike[] = [user]
    thread = applyTextDelta(thread, 1, { text: 'The user is doing well', replace: true }, rebuilding)
    thread = applyTextDelta(thread, 1, { text: ' and has been actively planning', replace: false }, rebuilding)
    expect(thread.map((m) => m.id)).toEqual(['turn:1:message:0', streamMessageID(1)])
    expect(textOfAssistant(thread)).toEqual(['The user is doing well and has been actively planning'])
  })

  it('ignores an increment that arrives after the saved message already holds the whole reply', () => {
    // The reply streamed in under a second: the saved message reached the client, then the last chunk.
    const rebuilding = new Set<number>([1]) // the stream's first delta (a replace) was applied...
    finishStreamedText(rebuilding, 1) // ...and then the saved message arrived
    const thread = applyTextDelta([user, durable(FULL)], 1, { text: ' They are currently in California.', replace: false }, rebuilding)
    expect(textOfAssistant(thread)).toEqual([FULL])
  })

  it('ignores every late increment, not just the first', () => {
    const rebuilding = new Set<number>()
    let thread: ThreadMessageLike[] = [user, durable(FULL)]
    for (const text of [' They are', ' currently in', ' California.']) {
      thread = applyTextDelta(thread, 1, { text, replace: false }, rebuilding)
    }
    expect(textOfAssistant(thread)).toEqual([FULL])
  })

  it('still lets a replace snapshot set the text of a saved message (cold replay)', () => {
    const thread = applyTextDelta([user, durable('The user is')], 1, { text: FULL, replace: true }, new Set())
    expect(textOfAssistant(thread)).toEqual([FULL])
  })

  it('rebuilds the reply on a cold replay: saved message first, then the stream as a snapshot plus increments', () => {
    const rebuilding = new Set<number>()
    let thread: ThreadMessageLike[] = [user, durable(FULL)]
    thread = applyTextDelta(thread, 1, { text: 'The user is doing well', replace: true }, rebuilding)
    thread = applyTextDelta(thread, 1, { text: ' and has been actively planning a relaxed weekend trip.', replace: false }, rebuilding)
    thread = applyTextDelta(thread, 1, { text: ' They are currently in California.', replace: false }, rebuilding)
    expect(textOfAssistant(thread)).toEqual([FULL])
  })

  it('does not carry one turn’s build-up into the next', () => {
    const rebuilding = new Set<number>()
    applyTextDelta([user], 1, { text: 'a', replace: true }, rebuilding)
    finishStreamedText(rebuilding, 1)
    const durable2: ThreadMessageLike = { id: 'turn:2:message:2', role: 'assistant', content: [{ type: 'text', text: 'second reply' }] }
    const thread = applyTextDelta([durable2], 2, { text: ' extra', replace: false }, rebuilding)
    expect(textOfAssistant(thread)).toEqual(['second reply'])
  })
})
