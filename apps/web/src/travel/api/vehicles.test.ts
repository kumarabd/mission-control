import { afterEach, describe, expect, it, vi } from 'vitest'
import { deleteVehicle } from './vehicles'

const reply = (status: number, body = '') => new Response(body || null, { status })

describe('deleteVehicle', () => {
  afterEach(() => vi.unstubAllGlobals())

  it('removes the profile and the garage entry', async () => {
    const fetchMock = vi.fn().mockResolvedValue(reply(204))
    vi.stubGlobal('fetch', fetchMock)
    await deleteVehicle('1HGCV1F30LA000002')
    const calls = fetchMock.mock.calls.map(([url, init]) => `${init.method} ${url}`)
    expect(calls).toEqual([
      'DELETE /maps/api/v1/vehicles/1HGCV1F30LA000002',
      'DELETE /maps/api/v1/garage/vehicles/1HGCV1F30LA000002',
    ])
  })

  it('treats a vehicle that is already gone as removed, but not other failures', async () => {
    const notFound = JSON.stringify({ error: { code: 'NOT_FOUND', message: 'vehicle not found' } })
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(reply(404, notFound)))
    await expect(deleteVehicle('X')).resolves.toBeUndefined()

    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(reply(500, '{}')))
    await expect(deleteVehicle('X')).rejects.toMatchObject({ status: 500 })
  })
})
