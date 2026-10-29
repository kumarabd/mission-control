export type Page<T> = {
  items: T[]
  total?: number
  /** The engine's cursor: the offset of the next page, or null at the end. */
  next_offset?: number | null
}

export type Recurrence = {
  freq: 'daily' | 'weekly' | 'monthly' | string
  interval?: number
  weekdays?: number[]
}

export type LifeSettings = {
  id: string
  time_zone: string
  work_start: string
  work_end: string
  version: number
}

export type LifeErrorKind =
  | 'unauthorized'
  | 'not_provisioned'
  | 'not_found'
  | 'conflict'
  | 'retry'
  | 'invalid_input'
  | 'duplicate'
  | 'too_large'
  | 'busy'
  | 'engine'
  | 'server'
  | 'invalid_response'

export type LifeErrorEnvelope = {
  error?: string | { code?: string; message?: string }
  message?: string
}
