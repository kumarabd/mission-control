import { createContext, useContext } from 'react'

export type VoiceContextValue = {
  enabled: boolean
  supported: boolean
  setEnabled: (enabled: boolean) => void
}

export const VoiceContext = createContext<VoiceContextValue | null>(null)

export function useVoiceInput() {
  const context = useContext(VoiceContext)
  if (!context) throw new Error('useVoiceInput must be used within VoiceProvider')
  return context
}
