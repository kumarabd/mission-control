import { useCallback, useEffect, useMemo, useRef, useState } from 'react'

/**
 * Browser-native live voice: continuous speech recognition for the person's
 * turn, the gateway for the reply, and speech synthesis for the assistant's
 * answer. It is hands-free and turn-based; it is not a streaming audio model.
 */

type RecognitionResult = {
  isFinal: boolean
  readonly 0: { transcript: string }
  readonly length: number
}

type RecognitionEvent = {
  resultIndex: number
  results: {
    readonly length: number
    readonly [index: number]: RecognitionResult
  }
}

type RecognitionErrorEvent = { error: string; message?: string }

type SpeechRecognitionLike = {
  continuous: boolean
  interimResults: boolean
  lang: string
  maxAlternatives: number
  start: () => void
  stop: () => void
  abort: () => void
  onresult: ((event: RecognitionEvent) => void) | null
  onend: (() => void) | null
  onerror: ((event: RecognitionErrorEvent) => void) | null
}

type SpeechRecognitionConstructor = new () => SpeechRecognitionLike

function recognitionConstructor(): SpeechRecognitionConstructor | null {
  if (typeof window === 'undefined') return null
  const scope = window as unknown as {
    SpeechRecognition?: SpeechRecognitionConstructor
    webkitSpeechRecognition?: SpeechRecognitionConstructor
  }
  return scope.SpeechRecognition ?? scope.webkitSpeechRecognition ?? null
}

export function liveVoiceSupported(): boolean {
  return Boolean(recognitionConstructor() && typeof window !== 'undefined' && 'speechSynthesis' in window)
}

export type LiveVoiceStatus = 'idle' | 'listening' | 'thinking' | 'speaking'

function speechText(value: string): string {
  return value
    .replace(/```[\s\S]*?```/g, ' Code block omitted. ')
    .replace(/!\[(.*?)\]\(.*?\)/g, '$1')
    .replace(/\[(.*?)\]\(.*?\)/g, '$1')
    .replace(/[#>*_`~]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
}

export function useLiveVoice(onUtterance: (text: string) => boolean) {
  const supported = useMemo(() => liveVoiceSupported(), [])
  const [active, setActive] = useState(false)
  const [status, setStatus] = useState<LiveVoiceStatus>('idle')
  const [interim, setInterim] = useState('')
  const [error, setError] = useState<string | null>(null)

  const activeRef = useRef(false)
  const awaitingRef = useRef(false)
  const speakingRef = useRef(false)
  const recognitionRef = useRef<SpeechRecognitionLike | null>(null)
  const startRecognitionRef = useRef<() => void>(() => {})
  const restartTimerRef = useRef<number | null>(null)
  const awaitingTimerRef = useRef<number | null>(null)
  const onUtteranceRef = useRef(onUtterance)

  useEffect(() => {
    onUtteranceRef.current = onUtterance
  }, [onUtterance])

  const clearTimers = useCallback(() => {
    if (restartTimerRef.current != null) window.clearTimeout(restartTimerRef.current)
    if (awaitingTimerRef.current != null) window.clearTimeout(awaitingTimerRef.current)
    restartTimerRef.current = null
    awaitingTimerRef.current = null
  }, [])

  const stop = useCallback(() => {
    activeRef.current = false
    awaitingRef.current = false
    speakingRef.current = false
    clearTimers()
    const recognition = recognitionRef.current
    recognitionRef.current = null
    try {
      recognition?.abort()
    } catch {
      /* already stopped */
    }
    window.speechSynthesis?.cancel()
    setActive(false)
    setStatus('idle')
    setInterim('')
    setError(null)
  }, [clearTimers])

  const startRecognition = useCallback(() => {
    if (!activeRef.current || recognitionRef.current) return
    const Constructor = recognitionConstructor()
    if (!Constructor) return
    const recognition = new Constructor()
    recognition.continuous = true
    recognition.interimResults = true
    recognition.lang = navigator.language || 'en-US'
    recognition.maxAlternatives = 1

    recognition.onresult = (event) => {
      let finalText = ''
      let partial = ''
      for (let index = event.resultIndex; index < event.results.length; index += 1) {
        const result = event.results[index]
        const transcript = result?.[0]?.transcript ?? ''
        if (result.isFinal) finalText += transcript
        else partial += transcript
      }
      if (partial) setInterim(partial.trim())
      const spoken = finalText.trim()
      // Safari finalizes a bare "." or "," for background noise; no letters or
      // digits means nothing was said, so don't send a turn.
      if (!spoken || !/[\p{L}\p{N}]/u.test(spoken)) return
      setInterim('')
      const accepted = onUtteranceRef.current(spoken)
      if (!accepted) {
        setError('That answer didn’t match. Try again, or tap one of the options.')
        return
      }
      awaitingRef.current = true
      setStatus('thinking')
      setError(null)
      try {
        recognition.stop()
      } catch {
        /* it may already be stopping */
      }
      if (awaitingTimerRef.current != null) window.clearTimeout(awaitingTimerRef.current)
      awaitingTimerRef.current = window.setTimeout(() => {
        if (!awaitingRef.current || !activeRef.current) return
        awaitingRef.current = false
        setStatus('listening')
        startRecognitionRef.current()
      }, 90_000)
    }

    recognition.onerror = (event) => {
      if (event.error === 'aborted' || event.error === 'no-speech') return
      if (event.error === 'not-allowed' || event.error === 'service-not-allowed') {
        activeRef.current = false
        recognitionRef.current = null
        setActive(false)
        setStatus('idle')
        setError('Microphone access is needed for live voice.')
        return
      }
      setError(`Voice input stopped: ${event.error}.`)
    }

    recognition.onend = () => {
      recognitionRef.current = null
      if (!activeRef.current || awaitingRef.current || speakingRef.current) return
      if (restartTimerRef.current != null) return
      restartTimerRef.current = window.setTimeout(() => {
        restartTimerRef.current = null
        if (activeRef.current && !awaitingRef.current && !speakingRef.current) {
          startRecognitionRef.current()
        }
      }, 300)
    }

    recognitionRef.current = recognition
    try {
      recognition.start()
      setStatus('listening')
    } catch (cause) {
      recognitionRef.current = null
      setError(cause instanceof Error ? cause.message : 'Live voice could not start.')
    }
  }, [])

  useEffect(() => {
    startRecognitionRef.current = startRecognition
  }, [startRecognition])

  const speak = useCallback(
    (text: string) => {
      const spoken = speechText(text)
      const resume = () => {
        speakingRef.current = false
        if (!activeRef.current) {
          setStatus('idle')
          return
        }
        setStatus('listening')
        startRecognitionRef.current()
      }
      if (!spoken) {
        resume()
        return
      }
      speakingRef.current = true
      awaitingRef.current = false
      setStatus('speaking')
      window.speechSynthesis.cancel()
      const utterance = new SpeechSynthesisUtterance(spoken)
      utterance.lang = navigator.language || 'en-US'
      utterance.onend = resume
      utterance.onerror = resume
      window.speechSynthesis.speak(utterance)
    },
    [],
  )

  const noteAssistantDone = useCallback(
    (text: string) => {
      if (!activeRef.current || !awaitingRef.current) return
      awaitingRef.current = false
      if (awaitingTimerRef.current != null) {
        window.clearTimeout(awaitingTimerRef.current)
        awaitingTimerRef.current = null
      }
      speak(text)
    },
    [speak],
  )

  const start = useCallback(() => {
    if (!supported) {
      setError('Live voice is not available in this browser.')
      return
    }
    activeRef.current = true
    awaitingRef.current = false
    speakingRef.current = false
    setActive(true)
    setError(null)
    setStatus('listening')
    startRecognition()
  }, [startRecognition, supported])

  useEffect(() => {
    return () => {
      activeRef.current = false
      awaitingRef.current = false
      speakingRef.current = false
      clearTimers()
      try {
        recognitionRef.current?.abort()
      } catch {
        /* already stopped */
      }
      recognitionRef.current = null
      window.speechSynthesis?.cancel()
    }
  }, [clearTimers])

  return {
    supported,
    active,
    status,
    interim,
    error,
    start,
    stop,
    noteAssistantDone,
  }
}
