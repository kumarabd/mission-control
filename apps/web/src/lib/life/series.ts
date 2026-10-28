import { useQuery } from '@tanstack/react-query'
import { providerRequest, isLifeError } from './client'
import { lifeKeys } from './queryKeys'
import { seriesRange } from './time'
import type { MetricSource, SeriesData } from './wire'

/**
 * A bound metric's values, read live from its data provider through the router. A missing period is a gap and an
 * unreachable provider is an error: callers show both, never zero or a stale chart.
 */
export function useSeries(source: MetricSource | null | undefined, days = 90) {
  const range = seriesRange(days)
  const granularity = 'day'
  return useQuery({
    queryKey: lifeKeys.series(source?.provider ?? '', source?.series ?? '', range.from, range.to, granularity),
    queryFn: ({ signal }) =>
      providerRequest<SeriesData>(
        source!.provider,
        'series_get',
        { series: source!.series, from: range.from, to: range.to, granularity },
        { signal },
      ),
    enabled: Boolean(source),
    retry: (failureCount, error) => isLifeError(error) && error.kind === 'retry' && failureCount < 2,
    staleTime: 60_000,
  })
}
