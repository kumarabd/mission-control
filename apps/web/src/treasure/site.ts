import { useEffect } from 'react'

export const CONTACT_EMAIL = 'abishekkumar92@gmail.com'
export const OPERATOR = 'Abishek Kumar Karuppasamy'

export function usePageTitle(title: string, description: string) {
  useEffect(() => {
    const prev = document.title
    document.title = title
    const meta = document.querySelector('meta[name="description"]')
    const prevDesc = meta?.getAttribute('content') ?? ''
    meta?.setAttribute('content', description)
    // These pages are Treasure's, not the console's: show Treasure's icon in the tab and in link previews.
    const icons = Array.from(document.querySelectorAll<HTMLLinkElement>('link[rel="icon"], link[rel="apple-touch-icon"]'))
    const prevIcons = icons.map((l) => [l, l.href, l.type] as const)
    icons.forEach((l) => { l.href = '/treasure-icon.png'; l.type = 'image/png' })
    const og = Array.from(document.querySelectorAll<HTMLMetaElement>('meta[property="og:title"], meta[property="og:image"], meta[name="twitter:title"]'))
    const prevOg = og.map((m) => [m, m.content] as const)
    og.forEach((m) => { m.content = m.getAttribute('property') === 'og:image' ? '/treasure-icon.png' : title })
    return () => {
      document.title = prev; meta?.setAttribute('content', prevDesc)
      prevIcons.forEach(([l, h, t]) => { l.href = h; l.type = t })
      prevOg.forEach(([m, c]) => { m.content = c })
    }
  }, [title, description])
}

