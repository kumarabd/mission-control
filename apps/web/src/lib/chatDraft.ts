import { create } from 'zustand'

type ChatDraftState = {
  draft: string
  /** Bumped on every request so Chat can apply the same text twice in a row. */
  requestId: number
  request: (text: string) => void
  clear: () => void
}

/**
 * A small handoff for “talk to your assistant” actions elsewhere in the
 * console. Chat consumes the draft once, focuses the composer, and clears it.
 */
export const useChatDraft = create<ChatDraftState>((set) => ({
  draft: '',
  requestId: 0,
  request: (text) => set((state) => ({ draft: text, requestId: state.requestId + 1 })),
  clear: () => set({ draft: '' }),
}))
