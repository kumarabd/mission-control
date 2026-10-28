// Runs the vectors every client's evaluator must pass (the engine's viewkit-vectors.json), in UTC with Monday weeks.
process.env.TZ = 'UTC'

import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { bucketed, kitData, sentence, sentenceParts, evaluate, parseKitDate, type KitData } from './viewkit'
import type { Calc, KitWindow, Slot } from './wire'

type Vectors = {
  now: string
  datasets: Record<string, Record<string, [string, number][]>>
  cases: { name: string; data: string; calc: Calc; expect: number | string; eps?: number }[]
  sentences: { name: string; data: string; locale: string; text: string; slots: Record<string, Slot>; expect: string | null; expect_parts?: [string, boolean][] | null }[]
  buckets: { name: string; data: string; metric: string; window: KitWindow; bucket: string; aggregate: string; expect: number[] }[]
}
const vectors = JSON.parse(readFileSync(new URL('./viewkit-vectors.json', import.meta.url), 'utf8')) as Vectors

function data(name: string): KitData {
  const series: KitData['series'] = {}
  for (const [metric, rows] of Object.entries(vectors.datasets[name])) series[metric] = rows.map(([day, value]) => ({ date: parseKitDate(day)!, value }))
  return kitData(series, new Date(vectors.now))
}
const day = (d: Date) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`

describe('view kit evaluator', () => {
  for (const c of vectors.cases) {
    it(c.name, () => {
      const got = evaluate(c.calc, data(c.data))
      if (c.expect === 'unknown') expect(got).toBeNull()
      else if (typeof c.expect === 'string') expect(got instanceof Date ? day(got) : got).toBe(c.expect)
      else expect(Math.abs((got as number) - c.expect)).toBeLessThanOrEqual(c.eps ?? 0.01)
    })
  }
  for (const s of vectors.sentences) {
    it(s.name, () => {
      expect(sentence(s.text, s.slots, data(s.data), s.locale)).toBe(s.expect)
      if ('expect_parts' in s) {
        const parts = sentenceParts(s.text, s.slots, data(s.data), s.locale)
        expect(parts?.map((p) => [p.text, p.figure]) ?? null).toEqual(s.expect_parts ?? null)
      }
    })
  }
  for (const b of vectors.buckets) {
    it(b.name, () => expect(bucketed(b.metric, b.window, b.bucket, b.aggregate, data(b.data))?.map((p) => p.value)).toEqual(b.expect))
  }
})
