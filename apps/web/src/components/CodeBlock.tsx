import Button from './ui/Button'

export default function CodeBlock({ code, label }: { code: string; label: string }) {
  const copy = () => navigator.clipboard.writeText(code)
  return (
    <div className="overflow-hidden rounded-lg bg-flat-surface">
      <div className="flex items-center justify-between bg-flat-muted px-4 py-2">
        <span className="text-xs font-semibold uppercase tracking-wider text-flat-muted-fg">{label}</span>
        <Button variant="outline" className="h-10 min-h-0 rounded-md px-3 text-xs" onClick={copy}>
          Copy
        </Button>
      </div>
      <pre className="overflow-x-auto p-4 font-mono text-xs font-normal leading-relaxed">{code}</pre>
    </div>
  )
}
