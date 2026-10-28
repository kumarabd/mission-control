import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
// Self-hosted fonts. Imported here, not via CSS @import, so Vite resolves and bundles the font files.
import '@fontsource-variable/hanken-grotesk/wght.css'
import '@fontsource/ibm-plex-mono/latin-400.css'
import '@fontsource/ibm-plex-mono/latin-500.css'
import './index.css'
import App from './App.tsx'

createRoot(document.getElementById('root')!).render(
 <StrictMode>
 <App />
 </StrictMode>,
)
