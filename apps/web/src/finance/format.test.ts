import { describe, expect, it } from 'vitest'
import { formatDate, formatMoney, monthWindow } from './format'

describe('finance display semantics', () => {
  it('retains cents beyond both JavaScript and Int64 integer ranges', () => {
    expect(formatMoney('90071992547409919999', 'USD', 'en-US')).toBe('$900,719,925,474,099,199.99')
  })
  it('uses the currency exponent and handles refunds smaller than a whole unit', () => {
    expect(formatMoney(500, 'JPY', 'en-US')).toBe('¥500')
    expect(formatMoney('1250', 'KWD', 'en-US')).toMatch(/1\.250/)
    expect(formatMoney('-50', 'USD', 'en-US')).toBe('-$0.50')
    expect(formatMoney('0', 'USD', 'en-US')).toBe('$0.00')
  })
  it('preserves a calendar date and computes month bounds using the local date', () => {
    expect(monthWindow(new Date(2026, 9, 4, 23))).toEqual({ from: '2026-10-01', to: '2026-10-04' })
    expect(formatDate('2026-10-04')).toBe(new Intl.DateTimeFormat(undefined, { dateStyle: 'medium' }).format(new Date(2026, 9, 4, 12)))
  })
})
