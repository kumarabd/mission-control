/**
 * Some models behind the gateway put their text tool-call protocol in the
 * content stream: `<tool_call>`, then `<function=…>` and `<parameter=…>`
 * inside. That is the call's transport, not something the assistant said, so
 * it is never drawn. A closed call is removed whole; when its opener is still
 * arriving, or came before the text kept (a question prompt sliced out of a
 * call), everything from the first leftover marker on is dropped.
 */
const MARKERS = ['<tool_call', '</tool_call', '<function', '</function', '<parameter', '</parameter']

export function stripToolCallText(text: string): string {
  if (!MARKERS.some((marker) => text.includes(marker))) return text
  let value = text.replace(/<tool_call[^>]*>[\s\S]*?<\/tool_call>/g, '')
  let cut = -1
  for (const marker of MARKERS) {
    const index = value.indexOf(marker)
    if (index >= 0 && (cut < 0 || index < cut)) cut = index
  }
  if (cut >= 0) value = value.slice(0, cut)
  return value.trim()
}
