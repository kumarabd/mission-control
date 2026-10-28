export const REQUEST_TIMEOUT_MS = 20_000

export class RequestTimeoutError extends Error {
  constructor() {
    super('Request timed out. Check your connection and try again.')
    this.name = 'RequestTimeoutError'
  }
}

/**
 * Fetch does not impose a timeout. Keep one bounded request from leaving a
 * screen permanently pending, while preserving a caller-provided abort signal.
 */
export async function fetchWithTimeout(
  input: RequestInfo | URL,
  init: RequestInit = {},
  timeoutMs = REQUEST_TIMEOUT_MS,
): Promise<Response> {
  const controller = new AbortController()
  let timedOut = false
  const forwardAbort = () => controller.abort(init.signal?.reason)
  if (init.signal?.aborted) forwardAbort()
  else init.signal?.addEventListener('abort', forwardAbort, { once: true })

  const timer = window.setTimeout(() => {
    timedOut = true
    controller.abort()
  }, timeoutMs)

  try {
    return await fetch(input, { ...init, signal: controller.signal })
  } catch (error) {
    if (timedOut) throw new RequestTimeoutError()
    throw error
  } finally {
    window.clearTimeout(timer)
    init.signal?.removeEventListener('abort', forwardAbort)
  }
}
