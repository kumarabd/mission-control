export type MetricReading = { value: number; metricName: string }

export type PerformanceMetrics = {
  ttft?: MetricReading
  tpot?: MetricReading
  requestLatency?: MetricReading
  tokensPerSecond?: MetricReading
}

type Sample = MetricReading

const METRIC_MATCHERS: Record<keyof PerformanceMetrics, string[]> = {
  ttft: ['ttft', 'time_to_first_token', 'first_token_latency'],
  tpot: ['tpot', 'time_per_output_token', 'time_between_tokens', 'inter_token_latency'],
  requestLatency: ['request_duration', 'generation_duration', 'llm_latency'],
  tokensPerSecond: ['tokens_per_second', 'tokens_per_sec', 'generation_rate'],
}

function samplesFromPrometheus(body: string): Sample[] {
  return body.split('\n').filter((line) => line && !line.startsWith('#')).flatMap((line) => {
    const match = line.match(/^([a-zA-Z_:][a-zA-Z0-9_:]*)(?:\{[^}]*\})?\s+([-+.0-9eE]+)$/)
    if (!match) return []
    const value = Number(match[2])
    return Number.isFinite(value) ? [{ metricName: match[1], value }] : []
  })
}

function selectMetric(samples: Sample[], terms: string[]): MetricReading | undefined {
  const matching = samples.filter((sample) => {
    const name = sample.metricName.toLowerCase()
    return terms.some((term) => name.includes(term)) && !name.endsWith('_bucket')
  })
  if (matching.length === 0) return undefined
  const sum = matching.find((sample) => sample.metricName.endsWith('_sum'))
  if (sum) {
    const count = matching.find((sample) => sample.metricName === sum.metricName.replace(/_sum$/, '_count'))
    if (count && count.value > 0) return { metricName: sum.metricName.replace(/_sum$/, ''), value: sum.value / count.value }
  }
  return matching.find((sample) => !sample.metricName.endsWith('_count') && !sample.metricName.endsWith('_sum')) ?? matching[0]
}

/** Extract common LLM latency and throughput measures from Prometheus text. */
export function parsePerformanceMetrics(body: string): PerformanceMetrics {
  const samples = samplesFromPrometheus(body)
  return {
    ttft: selectMetric(samples, METRIC_MATCHERS.ttft),
    tpot: selectMetric(samples, METRIC_MATCHERS.tpot),
    requestLatency: selectMetric(samples, METRIC_MATCHERS.requestLatency),
    tokensPerSecond: selectMetric(samples, METRIC_MATCHERS.tokensPerSecond),
  }
}
