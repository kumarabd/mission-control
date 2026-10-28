import { useCallback, useState } from 'react'

const COLLAPSE_KEY = 'mission-control.sidebar.collapsed'
const LEGACY_COLLAPSE_KEY = 'brainstorm.sidebar.collapsed'

export function useSidebarCollapsed() {
  const [collapsed, setCollapsed] = useState<boolean>(() => {
    try {
      return (localStorage.getItem(COLLAPSE_KEY) ?? localStorage.getItem(LEGACY_COLLAPSE_KEY)) === 'true'
    } catch {
      return false
    }
  })
  const toggle = useCallback(() => {
    setCollapsed((c) => {
      const next = !c
      try {
        localStorage.setItem(COLLAPSE_KEY, String(next))
      } catch {
        /* ignore */
      }
      return next
    })
  }, [])
  return { collapsed, toggle }
}
