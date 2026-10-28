/**
 * Where the travel pages reach the signed-in user's own maps-engine: through the router, at `<router>/maps/api/v1`,
 * with their Clerk session token. The router comes from the runtime config the image renders at start
 * (window.__RUNTIME_CONFIG__.ROUTER_BASE_URL, the same one the gateway client uses), else a build-time override.
 * In dev the Vite proxy forwards `/maps` (see vite.config.ts).
 */
const runtime = ((typeof window !== 'undefined' ? window.__RUNTIME_CONFIG__?.ROUTER_BASE_URL : '') ?? '').trim().replace(/\/$/, '')
const configured = (import.meta.env.VITE_MAPS_BASE_URL ?? '').trim().replace(/\/$/, '')
// The gateway lives on the same router (`<router>/gateway`), so its base tells us the router's origin.
const gateway = (import.meta.env.VITE_GATEWAY_BASE_URL ?? '').trim().replace(/\/gateway\/?$/, '')

export const MAPS_API_BASE = `${runtime ? `${runtime}/maps` : configured || (gateway ? `${gateway}/maps` : '/maps')}/api/v1`

export const GOOGLE_MAPS_API_KEY = (import.meta.env.VITE_GOOGLE_MAPS_API_KEY ?? '').trim()
