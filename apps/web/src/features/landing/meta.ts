import { useEffect } from 'react'

function setMeta(name: string, content: string) {
  let element = document.querySelector<HTMLMetaElement>(`meta[name="${name}"]`)
  if (!element) {
    element = document.createElement('meta')
    element.name = name
    document.head.appendChild(element)
  }
  element.content = content
}

/** Keep the document title and description in sync with the public route. */
export function usePageMeta(title: string, description: string) {
  useEffect(() => {
    document.title = title
    setMeta('description', description)
  }, [title, description])
}
