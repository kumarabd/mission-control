import { describe, expect, it } from 'vitest'
import { seriesRange } from './time'

describe('series window', () => {
  it('ends today and starts the given number of days earlier', () => {
    const now = new Date(2026, 9, 18, 15, 30)
    expect(seriesRange(90, now)).toEqual({ from: '2026-07-20', to: '2026-10-18' })
    expect(seriesRange(7, now)).toEqual({ from: '2026-10-11', to: '2026-10-18' })
  })
})
