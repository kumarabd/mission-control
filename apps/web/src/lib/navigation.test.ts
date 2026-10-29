import { describe, expect, it } from 'vitest'
import { ALL_NAV_ITEMS, LEGACY_REDIRECTS, isNavActive } from './navigation'

const redirect = (from: string) => LEGACY_REDIRECTS.find((entry) => entry.from === from)

describe('Mission Control navigation', () => {
  it('keeps the native order first and Settings last', () => {
    expect(ALL_NAV_ITEMS.map((item) => item.label)).toEqual([
      'Today',
      'Life',
      'Chat',
      'Memory',
      'Finance',
      'Travel',
      'Settings',
    ])
  })

  it('sends the old console landing and Review to Today', () => {
    expect(redirect('/home')?.to).toBe('/today')
    expect(redirect('/review')).toMatchObject({ to: '/today', prefix: true })
    expect(redirect('/console')?.to).toBe('/today')
  })

  it('moves raw memory tables and operations under Advanced', () => {
    expect(redirect('/memory/units')?.to).toBe('/settings/advanced/raw?table=memory_unit')
    expect(redirect('/memory/entities')?.to).toBe('/settings/advanced/raw?table=entity')
    expect(redirect('/metrics')?.to).toBe('/settings/advanced/health')
    expect(redirect('/audit')?.to).toBe('/settings/advanced/activity')
    expect(redirect('/settings/personas')?.to).toBe('/settings/agents')
  })

  it('matches detail routes through the section prefix', () => {
    const life = ALL_NAV_ITEMS.find((item) => item.label === 'Life')!
    expect(isNavActive('/life', life)).toBe(true)
    expect(isNavActive('/life/anything', life)).toBe(true)
    expect(isNavActive('/today', life)).toBe(false)
  })
})
