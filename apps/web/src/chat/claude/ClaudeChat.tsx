import {
  ActionBarPrimitive,
  AuiIf,
  ComposerPrimitive,
  MessagePrimitive,
  ThreadPrimitive,
  useToolCallElapsed,
  type ToolCallMessagePartProps,
} from '@assistant-ui/react'
import {
  ArrowUpIcon,
  CheckCircle2,
  CheckIcon,
  ChevronRight,
  ClipboardIcon,
  LoaderCircle,
  Mic,
  Wrench,
  XCircle,
} from 'lucide-react'
import { type FC, type ReactNode } from 'react'
import { AgentAvatar, type AgentIdentity } from '../AgentAvatar'
import { MarkdownText } from './markdown-text'

// Adapted from assistant-ui's official "Claude Clone" example
// (assistant-ui.com/examples/claude), recolored to this app's own flat-*
// design tokens (src/themes.css) and Outfit font instead of Claude's cream
// / serif palette — flat-* are CSS custom properties that already swap
// per data-theme, so no dark: variants are needed here.
//
// The mode tabs are decorative — there's no backend behind "Write / Learn
// / Code / From Drive / From Calendar" (the model picker from the original
// example was removed outright: this app routes to one gateway-selected
// model, nothing for it to pick). Edit and Reload are omitted from
// the action bar: useGatewayThread's runtime (src/chat/useGatewayThread.ts)
// has no onEdit/onReload — the Gateway is an append-only turn log with no
// regenerate/edit endpoint — and ActionBarPrimitive.Edit/.Reload call the
// runtime unconditionally, throwing "Runtime does not support X" on click
// rather than disabling themselves. Feedback is wired to a client-side-only
// adapter (toggles, nothing persisted) so it doesn't throw either.
// Attachments render but there's no attachment adapter wired to the
// gateway yet.
const iconButtonClassName =
  'flex size-8 items-center justify-center rounded-full text-flat-muted-fg transition-colors hover:bg-flat-muted hover:text-flat-foreground disabled:pointer-events-none disabled:opacity-40'

const roundActionClassName =
  'flex size-10 shrink-0 items-center justify-center rounded-full transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-flat-primary focus-visible:ring-offset-2 focus-visible:ring-offset-flat-surface disabled:pointer-events-none disabled:opacity-40'

function friendlyToolName(name: string): string {
  return name
    .replace(/[_-]+/g, ' ')
    .replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function displayJSON(value: unknown): string {
  if (typeof value === 'string') return value
  try {
    return JSON.stringify(value, null, 2)
  } catch {
    return String(value)
  }
}

const ToolActivity: FC<ToolCallMessagePartProps> = ({
  toolName,
  args,
  result,
  isError,
  status,
  providerMetadata,
}) => {
  const elapsed = useToolCallElapsed()
  const gateway = providerMetadata?.gateway as Record<string, unknown> | undefined
  const serverStatus = typeof gateway?.status === 'string' ? gateway.status : undefined
  const partialOutput = typeof gateway?.partialOutput === 'string' ? gateway.partialOutput : ''
  const running = serverStatus ? serverStatus === 'pending' : status.type === 'running'
  const cancelled = serverStatus === 'cancelled'
  const failed = serverStatus === 'error' || isError || status.type === 'incomplete'
  const details =
    result === undefined
      ? partialOutput
        ? { input: args, outputSoFar: partialOutput }
        : args
      : { input: args, output: result }

  return (
    <details className="group/details py-1">
      <summary className="flex min-w-0 cursor-pointer list-none items-center gap-2 rounded-sm text-sm leading-5 hover:bg-flat-muted/70 [&::-webkit-details-marker]:hidden">
        {running ? (
          <LoaderCircle className="size-3.5 shrink-0 animate-spin text-flat-primary" aria-hidden />
        ) : failed ? (
          <XCircle className="size-3.5 shrink-0 text-flat-danger" aria-hidden />
        ) : (
          <CheckCircle2 className="size-3.5 shrink-0 text-flat-success" aria-hidden />
        )}
        <Wrench className="size-3.5 shrink-0 text-flat-muted-fg" aria-hidden />
        <span className="min-w-0 flex-1 truncate font-medium text-flat-foreground">
          {friendlyToolName(toolName)}
        </span>
        <span className="shrink-0 text-xs text-flat-subtle-fg">
          {running ? 'Running' : cancelled ? 'Cancelled' : failed ? 'Failed' : 'Done'}
          {elapsed != null ? ` · ${(elapsed / 1000).toFixed(elapsed < 10_000 ? 1 : 0)}s` : ''}
        </span>
        <span className="sr-only">View tool details</span>
        <ChevronRight className="size-3 shrink-0 text-flat-subtle-fg transition-transform group-open/details:rotate-90" aria-hidden />
      </summary>
      <pre className="mt-1.5 max-h-56 overflow-auto rounded-sm border border-flat-border bg-flat-muted p-2 font-mono text-xs whitespace-pre-wrap text-flat-muted-fg">
        {displayJSON(details)}
      </pre>
    </details>
  )
}

const ToolActivityFeed: FC<{ children?: ReactNode }> = ({ children }) => {
  return (
    <div className="my-2 space-y-0.5 rounded-xl border border-flat-border bg-flat-muted/40 px-3 py-1.5">
      {children}
    </div>
  )
}

export const ClaudeChat: FC<{
  agent: AgentIdentity
  headerSlot?: ReactNode
  transcriptSlot?: ReactNode
  footerSlot?: ReactNode
}> = ({ agent, headerSlot, transcriptSlot, footerSlot }) => {
  return (
    <ThreadPrimitive.Root className="flex h-full flex-col items-stretch bg-flat-background text-flat-foreground">
      {headerSlot}

      <AuiIf condition={(s) => s.thread.isEmpty}>
        <EmptyState footerSlot={footerSlot} />
      </AuiIf>

      <AuiIf condition={(s) => !s.thread.isEmpty}>
        <ThreadPrimitive.Viewport className="flex grow flex-col overflow-y-auto px-4 pt-5 sm:px-6">
          <ThreadPrimitive.Messages>{() => <ChatMessage agent={agent} />}</ThreadPrimitive.Messages>

          <AuiIf condition={(s) => s.thread.isRunning}>
            <div
              className="mx-auto flex w-full max-w-3xl items-center gap-2 py-2 text-native-footnote text-flat-muted-fg"
              aria-live="polite"
            >
              <LoaderCircle className="size-4 animate-spin motion-reduce:animate-none" aria-hidden />
              Thinking…
            </div>
          </AuiIf>

          {transcriptSlot}

          <ThreadPrimitive.ViewportFooter className="sticky bottom-0 mx-auto mt-auto w-full max-w-3xl bg-linear-to-b from-transparent via-flat-background/85 to-flat-background pt-4 pb-2">
            {footerSlot}
            <Composer />
          </ThreadPrimitive.ViewportFooter>
        </ThreadPrimitive.Viewport>
      </AuiIf>
    </ThreadPrimitive.Root>
  )
}

const EmptyState: FC<{ footerSlot?: ReactNode }> = ({ footerSlot }) => {
  return (
    <div className="flex grow flex-col px-4 pt-5 sm:px-6">
      <div className="mx-auto w-full max-w-3xl">
        <p className="text-native-footnote leading-relaxed text-flat-muted-fg">
          Ask for anything: “remind me to call Sam tomorrow at 5pm”, “I want to drink more
          water”, “what should I do with 20 minutes?” Type, or tap the microphone and talk.
        </p>
      </div>
      <div className="mx-auto mt-auto w-full max-w-3xl pb-2">
        {footerSlot}
        <Composer />
      </div>
    </div>
  )
}

const Composer: FC = () => {
  return (
    <ComposerPrimitive.Root className="w-full rounded-2xl border border-flat-border bg-flat-surface p-2 transition-colors focus-within:border-flat-primary">
      <AuiIf condition={(s) => s.composer.dictation != null}>
        <div className="flex items-center gap-2 px-2 pb-1 text-2xs text-flat-primary" aria-live="polite">
          <span className="size-1.5 animate-pulse rounded-full bg-current" aria-hidden />
          <span>Listening</span>
          <ComposerPrimitive.DictationTranscript className="min-w-0 truncate text-flat-muted-fg" />
        </div>
      </AuiIf>
      <div className="flex items-end gap-1.5">
        <ComposerPrimitive.Input
          placeholder="Ask anything…"
          rows={1}
          className="block max-h-40 min-h-10 w-full min-w-0 flex-1 resize-none bg-transparent px-3 py-2 text-native-body text-flat-foreground outline-none placeholder:text-flat-muted-fg"
        />
        <ComposerActions />
      </div>
    </ComposerPrimitive.Root>
  )
}

const ComposerActions: FC = () => {
  return (
    <div className="flex items-center gap-1.5">
      <AuiIf condition={(s) => s.thread.isRunning}>
        <ComposerPrimitive.Cancel
          className={`${roundActionClassName} bg-flat-primary/60 text-flat-on-accent hover:bg-flat-primary`}
          aria-label="Stop"
        >
          <span className="size-2.5 rounded-[2px] bg-current" aria-hidden />
        </ComposerPrimitive.Cancel>
      </AuiIf>

      <AuiIf condition={(s) => !s.thread.isRunning && s.composer.dictation != null}>
        <ComposerPrimitive.StopDictation
          className={`${roundActionClassName} bg-flat-primary/60 text-flat-on-accent hover:bg-flat-primary`}
          aria-label="Stop dictation"
        >
          <span className="size-2.5 animate-pulse rounded-[2px] bg-current" aria-hidden />
        </ComposerPrimitive.StopDictation>
      </AuiIf>

      <AuiIf
        condition={(s) =>
          !s.thread.isRunning && s.composer.dictation == null && s.thread.capabilities.dictation
        }
      >
        <ComposerPrimitive.Dictate
          className={`${roundActionClassName} bg-flat-tint text-flat-primary hover:bg-flat-tint-soft`}
          aria-label="Dictate a message"
          title="Dictate a message"
        >
          <Mic className="size-5" aria-hidden />
        </ComposerPrimitive.Dictate>
      </AuiIf>

      <AuiIf condition={(s) => s.composer.dictation == null}>
        <ComposerPrimitive.Send
          className={`${roundActionClassName} bg-flat-primary text-flat-on-accent hover:bg-flat-primary-hover`}
          aria-label="Send"
        >
          <ArrowUpIcon className="size-5" aria-hidden />
        </ComposerPrimitive.Send>
      </AuiIf>
    </div>
  )
}

const ChatMessage: FC<{ agent: AgentIdentity }> = ({ agent }) => {
  return (
    <MessagePrimitive.Root className="group/message relative mx-auto flex w-full max-w-3xl flex-col py-2">
      <AuiIf condition={(s) => s.message.role === 'user'}>
        <div className="flex flex-col items-end gap-1">
          <div className="max-w-[85%] rounded-2xl border border-flat-border bg-flat-tint px-4 py-2.5 wrap-break-word whitespace-pre-wrap text-native-body text-flat-foreground">
            <MessagePrimitive.Parts components={{ Text: MarkdownText }} />
          </div>
          <ActionBarPrimitive.Root className="-mt-px flex items-center gap-0.5 opacity-0 transition-opacity group-focus-within/message:opacity-100 group-hover/message:opacity-100">
            <ActionBarPrimitive.Copy className={iconButtonClassName}>
              <AuiIf condition={(s) => s.message.isCopied}>
                <CheckIcon className="size-4" />
              </AuiIf>
              <AuiIf condition={(s) => !s.message.isCopied}>
                <ClipboardIcon className="size-4" />
              </AuiIf>
            </ActionBarPrimitive.Copy>
          </ActionBarPrimitive.Root>
        </div>
      </AuiIf>

      <AuiIf condition={(s) => s.message.role === 'assistant'}>
        <div className="flex items-start gap-2.5">
          <AgentAvatar agent={agent} size={28} className="mt-1" />
          <div className="flex min-w-0 flex-1 flex-col items-start">
            <div className="max-w-[88%] rounded-2xl border border-flat-border bg-flat-surface px-4 py-3 text-native-body leading-relaxed wrap-break-word text-flat-foreground">
              <MessagePrimitive.Parts
                components={{ Text: MarkdownText, tools: { Fallback: ToolActivity }, ToolGroup: ToolActivityFeed }}
                unstable_showEmptyOnNonTextEnd={false}
              />
            </div>
            <ActionBarPrimitive.Root className="mt-1 flex items-center gap-0.5 opacity-0 transition-opacity group-focus-within/message:opacity-100 group-hover/message:opacity-100">
              <ActionBarPrimitive.Copy className={iconButtonClassName}>
                <AuiIf condition={(s) => s.message.isCopied}>
                  <CheckIcon className="size-4" />
                </AuiIf>
                <AuiIf condition={(s) => !s.message.isCopied}>
                  <ClipboardIcon className="size-4" />
                </AuiIf>
              </ActionBarPrimitive.Copy>
            </ActionBarPrimitive.Root>
          </div>
        </div>
      </AuiIf>
    </MessagePrimitive.Root>
  )
}
