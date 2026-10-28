import { Component, type ErrorInfo, type ReactNode } from 'react'
import { AlertTriangle, RefreshCw } from 'lucide-react'

type Props = { children: ReactNode }
type State = { failed: boolean }

/** Keeps one failed screen from leaving the entire authenticated app blank. */
export default class AppErrorBoundary extends Component<Props, State> {
  state: State = { failed: false }

  static getDerivedStateFromError(): State {
    return { failed: true }
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    // Preserve diagnostics without exposing implementation details in the UI.
    console.error('Unhandled application error', error, info)
  }

  render() {
    if (!this.state.failed) return this.props.children

    return (
      <main className="flex min-h-screen items-center justify-center bg-flat-background p-6 text-flat-foreground">
        <section className="w-full max-w-md rounded-lg border border-flat-border bg-flat-surface p-6 shadow-2">
          <AlertTriangle className="size-6 text-flat-warning" aria-hidden />
          <h1 className="mt-4 text-xl font-semibold">This view needs to reload</h1>
          <p className="mt-2 text-base text-flat-muted-fg">
            Something unexpected interrupted this screen. Your data has not been changed.
          </p>
          <button
            type="button"
            onClick={() => window.location.reload()}
            className="mt-5 inline-flex h-9 items-center gap-2 rounded-md bg-flat-primary px-3.5 text-base font-medium text-flat-on-primary hover:bg-flat-primary-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-flat-primary focus-visible:ring-offset-2 focus-visible:ring-offset-flat-background"
          >
            <RefreshCw className="size-4" aria-hidden />
            Reload
          </button>
        </section>
      </main>
    )
  }
}
