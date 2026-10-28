import { useQuery } from '@tanstack/react-query'
import { Clock3, Gauge, TimerReset, Zap } from 'lucide-react'
import type { ReactNode } from 'react'
import PageHeader from '../components/ui/PageHeader'
import { getPerformanceMetrics, getReadyz } from '../lib/api'
import type { MetricReading } from '../lib/metrics'

function latencyValue(reading?: MetricReading) {
  if (!reading) return '—'
  const milliseconds = /second|_s$/.test(reading.metricName) ? reading.value * 1_000 : reading.value
  return `${milliseconds < 10 ? milliseconds.toFixed(1) : Math.round(milliseconds)} ms`
}

function rateValue(reading?: MetricReading) {
  if (!reading) return '—'
  return `${reading.value < 10 ? reading.value.toFixed(1) : Math.round(reading.value)} tok/s`
}

function MetricCard({ icon, label, value, detail }: { icon: ReactNode; label: string; value: string; detail: string }) {
  return (
    <div className="rounded-2xl border border-flat-border bg-flat-surface p-5">
      <span className="grid size-8 place-items-center rounded-lg bg-flat-tint text-flat-primary">{icon}</span>
      <p className="mt-4 text-sm text-flat-muted-fg">{label}</p>
      <p className="mt-0.5 text-3xl font-light tabular-nums tracking-tight text-flat-foreground">{value}</p>
      <p className="mt-1 font-mono text-xs text-flat-subtle-fg">{detail}</p>
    </div>
  )
}

export default function OpsLinks() {
  const metrics = useQuery({ queryKey: ['performance-metrics'], queryFn: getPerformanceMetrics, refetchInterval: 15_000 })
  const readiness = useQuery({ queryKey: ['readyz'], queryFn: getReadyz, refetchInterval: 15_000 })
  const values = metrics.data
  const checks = Object.entries(readiness.data?.checks ?? {})

  return (
    <div>
      <PageHeader
        title="Health"
        description="How quickly your assistant is responding right now. Updates every 15 seconds."
      />

      {metrics.isError && (
        <div className="mb-5 rounded-2xl border border-flat-warning/40 bg-flat-warning-muted px-5 py-3.5 text-sm text-flat-warning">
          Speed readings aren’t available from this deployment yet. Everything else keeps working.
        </div>
      )}

      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <MetricCard icon={<Zap className="size-4" />} label="First word" value={latencyValue(values?.ttft)} detail="time to first token" />
        <MetricCard icon={<TimerReset className="size-4" />} label="Each next word" value={latencyValue(values?.tpot)} detail="time per output token" />
        <MetricCard icon={<Clock3 className="size-4" />} label="Whole reply" value={latencyValue(values?.requestLatency)} detail="average request time" />
        <MetricCard icon={<Gauge className="size-4" />} label="Speed" value={rateValue(values?.tokensPerSecond)} detail="output tokens per second" />
      </div>

      <section className="mt-9">
        <h2 className="mb-3 text-lg font-medium tracking-tight">Services</h2>
        <div className="rounded-2xl border border-flat-border bg-flat-surface p-5">
          {readiness.isLoading && <p className="text-sm text-flat-muted-fg">Checking services…</p>}
          {readiness.isError && <p className="text-sm text-flat-danger">Couldn’t check services.</p>}
          {!readiness.isLoading && !readiness.isError && (
            <ul className="flex flex-wrap gap-2">
              {checks.map(([name, status]) => (
                <li key={name} className="inline-flex items-center gap-2 rounded-full border border-flat-border px-3.5 py-1.5 text-sm text-flat-foreground">
                  <span className={`size-2 rounded-full ${status === 'ok' ? 'bg-flat-success' : 'bg-flat-warning'}`} aria-hidden />
                  {name}
                  <span className="font-mono text-xs text-flat-subtle-fg">{status}</span>
                </li>
              ))}
              {checks.length === 0 && <li className="text-sm text-flat-muted-fg">No service checks reported.</li>}
            </ul>
          )}
        </div>
      </section>
    </div>
  )
}
