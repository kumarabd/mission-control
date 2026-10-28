import '@assistant-ui/react-markdown/styles/dot.css'

import {
  type CodeHeaderProps,
  MarkdownTextPrimitive,
  unstable_memoizeMarkdownComponents as memoizeMarkdownComponents,
  useIsMarkdownCodeBlock,
} from '@assistant-ui/react-markdown'
import remarkGfm from 'remark-gfm'
import { type FC, memo, useState } from 'react'
import { CheckIcon, CopyIcon } from 'lucide-react'
import { cn } from '../../lib/cn'
import { stripToolCallText } from '../toolCallText'

const MarkdownTextImpl = () => {
  return (
    <MarkdownTextPrimitive
      remarkPlugins={[remarkGfm]}
      className="aui-md"
      components={defaultComponents}
      preprocess={stripToolCallText}
      defer
    />
  )
}

export const MarkdownText = memo(MarkdownTextImpl)

const CodeHeader: FC<CodeHeaderProps> = ({ language, code }) => {
  const { isCopied, copyToClipboard } = useCopyToClipboard()
  const onCopy = () => {
    if (!code || isCopied) return
    copyToClipboard(code)
  }

  return (
    <div className="flex items-center justify-between rounded-t-md border border-b-0 border-flat-border bg-flat-muted px-3.5 py-1.5 text-xs">
      <span className="font-medium lowercase text-flat-muted-fg">{language}</span>
      <button
        type="button"
        aria-label="Copy code"
        onClick={onCopy}
        className="flex size-6 items-center justify-center rounded text-flat-muted-fg transition-colors hover:bg-flat-tint hover:text-flat-foreground"
      >
        {isCopied ? <CheckIcon className="size-3.5" /> : <CopyIcon className="size-3.5" />}
      </button>
    </div>
  )
}

function useCopyToClipboard({ copiedDuration = 3000 }: { copiedDuration?: number } = {}) {
  const [isCopied, setIsCopied] = useState(false)

  const copyToClipboard = (value: string) => {
    if (!value || typeof navigator === 'undefined' || !navigator.clipboard) {
      return
    }
    navigator.clipboard.writeText(value).then(() => {
      setIsCopied(true)
      setTimeout(() => setIsCopied(false), copiedDuration)
    })
  }

  return { isCopied, copyToClipboard }
}

const defaultComponents = memoizeMarkdownComponents({
  h1: ({ className, ...props }) => (
    <h1 className={cn('mt-5 mb-2 scroll-m-20 font-display text-xl font-bold first:mt-0 last:mb-0', className)} {...props} />
  ),
  h2: ({ className, ...props }) => (
    <h2 className={cn('mt-5 mb-2 scroll-m-20 font-display text-lg font-bold first:mt-0 last:mb-0', className)} {...props} />
  ),
  h3: ({ className, ...props }) => (
    <h3 className={cn('mt-4 mb-1.5 scroll-m-20 font-display text-base font-bold first:mt-0 last:mb-0', className)} {...props} />
  ),
  h4: ({ className, ...props }) => (
    <h4 className={cn('mt-3.5 mb-1 scroll-m-20 text-base font-semibold first:mt-0 last:mb-0', className)} {...props} />
  ),
  h5: ({ className, ...props }) => (
    <h5 className={cn('mt-3 mb-1 text-sm font-semibold first:mt-0 last:mb-0', className)} {...props} />
  ),
  h6: ({ className, ...props }) => (
    <h6 className={cn('mt-3 mb-1 text-sm font-semibold first:mt-0 last:mb-0', className)} {...props} />
  ),
  p: ({ className, ...props }) => <p className={cn('my-3 leading-relaxed first:mt-0 last:mb-0', className)} {...props} />,
  a: ({ className, ...props }) => (
    <a className={cn('text-flat-primary underline underline-offset-2 hover:text-flat-primary-hover', className)} {...props} />
  ),
  blockquote: ({ className, ...props }) => (
    <blockquote className={cn('my-3 border-s-2 border-flat-primary/40 ps-4 text-flat-muted-fg', className)} {...props} />
  ),
  ul: ({ className, ...props }) => (
    <ul className={cn('my-3 ms-5 list-disc marker:text-flat-muted-fg [&>li]:mt-1', className)} {...props} />
  ),
  ol: ({ className, ...props }) => (
    <ol className={cn('my-3 ms-5 list-decimal marker:text-flat-muted-fg [&>li]:mt-1', className)} {...props} />
  ),
  hr: ({ className, ...props }) => <hr className={cn('my-3 border-flat-border', className)} {...props} />,
  table: ({ className, ...props }) => (
    <table className={cn('my-3 w-full border-separate border-spacing-0 overflow-y-auto', className)} {...props} />
  ),
  th: ({ className, ...props }) => (
    <th
      className={cn('bg-flat-muted px-3 py-1.5 text-start font-medium first:rounded-ss-md last:rounded-se-md', className)}
      {...props}
    />
  ),
  td: ({ className, ...props }) => (
    <td className={cn('border-s border-b border-flat-border px-3 py-1.5 text-start last:border-e', className)} {...props} />
  ),
  tr: ({ className, ...props }) => (
    <tr
      className={cn(
        'm-0 border-b border-flat-border p-0 first:border-t [&:last-child>td:first-child]:rounded-es-md [&:last-child>td:last-child]:rounded-ee-md',
        className,
      )}
      {...props}
    />
  ),
  li: ({ className, ...props }) => <li className={cn('leading-relaxed', className)} {...props} />,
  strong: ({ className, ...props }) => <strong className={cn('font-semibold', className)} {...props} />,
  sup: ({ className, ...props }) => <sup className={cn('[&>a]:text-xs [&>a]:no-underline', className)} {...props} />,
  pre: ({ className, ...props }) => (
    <pre
      className={cn(
        'overflow-x-auto rounded-b-md border border-t-0 border-flat-border bg-flat-surface p-3.5 text-[13px] leading-relaxed',
        className,
      )}
      {...props}
    />
  ),
  code: function Code({ className, ...props }) {
    const isCodeBlock = useIsMarkdownCodeBlock()
    return (
      <code
        className={cn(!isCodeBlock && 'rounded-md bg-flat-muted px-1.5 py-0.5 font-mono text-[0.85em]', className)}
        {...props}
      />
    )
  },
  CodeHeader,
})
