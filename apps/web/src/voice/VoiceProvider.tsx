import { WebSpeechDictationAdapter } from '@assistant-ui/react'
import { useMemo, useState, type ReactNode } from 'react'
import { VoiceContext } from './voice-context'

const VOICE_INPUT_STORAGE_KEY = 'mission-control.voice-input'

export function VoiceProvider({ children }: { children: ReactNode }) {
  const supported = WebSpeechDictationAdapter.isSupported()
  const [enabled, setEnabledState] = useState(() => {
    try {
      return localStorage.getItem(VOICE_INPUT_STORAGE_KEY) !== 'false'
    } catch {
      return true
    }
  })

  const setEnabled = (next: boolean) => {
    setEnabledState(next)
    try {
      localStorage.setItem(VOICE_INPUT_STORAGE_KEY, String(next))
    } catch {
      // Voice remains a local enhancement when storage is unavailable.
    }
  }

  const value = useMemo(() => ({ enabled, supported, setEnabled }), [enabled, supported])
  return <VoiceContext.Provider value={value}>{children}</VoiceContext.Provider>
}
