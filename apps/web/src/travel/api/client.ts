import { isApiErrorResponse } from './contract/errors'
import { MAPS_API_BASE } from '../config'
import { getAuthToken } from '../token'

const BASE_URL = MAPS_API_BASE

export class ApiError extends Error {
  status: number
  /** For logging only; UI must not branch on this. */
  code?: string

  constructor(status: number, message: string, code?: string) {
    super(message)
    this.name = 'ApiError'
    this.status = status
    this.code = code
  }
}

async function request<T>(path: string, options?: RequestInit): Promise<T> {
  const token = await getAuthToken()
  const response = await fetch(`${BASE_URL}${path}`, {
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...options?.headers,
    },
    ...options,
  })

  if (!response.ok) {
    let message = `Request failed with status ${response.status}`
    let code: string | undefined
    try {
      const body: unknown = await response.json()
      if (isApiErrorResponse(body)) {
        message = body.error.message || message
        code = body.error.code
      } else if (body && typeof body === 'object' && typeof (body as { error?: unknown }).error === 'string') {
        // The router's own errors are {"error":"no_tenant"}.
        code = (body as { error: string }).error
        message = code
      }
    } catch {
      // non-JSON error body, use defaults
    }
    throw new ApiError(response.status, message, code)
  }

  if (response.status === 204) return undefined as T
  try {
    return (await response.json()) as T
  } catch {
    throw new ApiError(502, `Unexpected response from ${BASE_URL}${path}`, 'bad_response')
  }
}

export const api = {
  get<T>(path: string): Promise<T> {
    return request<T>(path)
  },
  post<T>(path: string, body: unknown): Promise<T> {
    return request<T>(path, {
      method: 'POST',
      body: JSON.stringify(body),
    })
  },
  delete(path: string): Promise<void> {
    return request<void>(path, { method: 'DELETE' })
  },
  put<T>(path: string, body: unknown): Promise<T> {
    return request<T>(path, {
      method: 'PUT',
      body: JSON.stringify(body),
    })
  },
}
