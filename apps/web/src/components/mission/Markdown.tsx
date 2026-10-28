import ReactMarkdown from 'react-markdown'
import remarkGfm from 'remark-gfm'
import { cn } from '../../lib/cn'

/** Native reading styles for assistant and memory content. */
export default function Markdown({ children, className }: { children: string; className?: string }) {
  return (
    <div
      className={cn(
        'text-native-body leading-relaxed text-flat-foreground',
        '[&_p]:my-2 [&_p:first-child]:mt-0 [&_p:last-child]:mb-0',
        '[&_h1]:mb-2 [&_h1]:mt-4 [&_h1]:text-native-headline [&_h2]:mb-2 [&_h2]:mt-4 [&_h2]:text-native-title3 [&_h3]:mb-1.5 [&_h3]:mt-3 [&_h3]:text-native-callout [&_h3]:font-semibold',
        '[&_ul]:my-2 [&_ul]:list-disc [&_ul]:pl-5 [&_ol]:my-2 [&_ol]:list-decimal [&_ol]:pl-5 [&_li]:my-1',
        '[&_strong]:font-semibold [&_em]:italic [&_a]:text-flat-primary [&_a]:underline [&_a]:underline-offset-2',
        '[&_code]:rounded [&_code]:bg-flat-muted [&_code]:px-1 [&_code]:py-0.5 [&_code]:font-mono [&_code]:text-sm',
        '[&_pre]:my-3 [&_pre]:overflow-x-auto [&_pre]:rounded-xl [&_pre]:border [&_pre]:border-flat-border [&_pre]:bg-flat-tint-soft [&_pre]:p-3',
        '[&_blockquote]:my-2 [&_blockquote]:border-l-2 [&_blockquote]:border-flat-border [&_blockquote]:pl-3 [&_blockquote]:text-flat-muted-fg',
        '[&_hr]:my-4 [&_hr]:border-flat-border [&_table]:my-3 [&_table]:w-full [&_table]:text-sm [&_th]:border-b [&_th]:border-flat-border [&_th]:px-2 [&_th]:py-1.5 [&_th]:text-left [&_td]:border-b [&_td]:border-flat-border [&_td]:px-2 [&_td]:py-1.5',
        className,
      )}
    >
      <ReactMarkdown remarkPlugins={[remarkGfm]}>{children}</ReactMarkdown>
    </div>
  )
}
