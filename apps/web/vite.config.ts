import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  const base = env.VITE_BASE_PATH || '/'

  // Dev proxy: VITE_DEV_API_PROXY or AGENT_BRAIN_API_URL (same name as Docker/nginx).
  const devApiTarget =
    process.env.VITE_DEV_API_PROXY ||
    process.env.AGENT_BRAIN_API_URL ||
    env.VITE_DEV_API_PROXY ||
    env.AGENT_BRAIN_API_URL ||
    'http://localhost:8080'

  // Same idea for the Gateway (docs/components/gateway/web.md) — defaults to
  // the port workflows/cmd/gateway's own GATEWAY_BIND_ADDRESS default binds.
  const devGatewayTarget =
    process.env.VITE_DEV_GATEWAY_PROXY ||
    process.env.GATEWAY_API_URL ||
    env.VITE_DEV_GATEWAY_PROXY ||
    env.GATEWAY_API_URL ||
    'http://localhost:8090'
  const devRouterTarget = process.env.VITE_DEV_ROUTER_PROXY || env.VITE_DEV_ROUTER_PROXY
  const useRouterProxy = Boolean(devRouterTarget)
  const apiProxyTarget = devRouterTarget || devApiTarget
  const gatewayProxyTarget = devRouterTarget || devGatewayTarget
  const routerBase = devRouterTarget?.replace(/\/$/, '')

  // Production generates this file at container start. Serving its equivalent
  // in router mode makes local development exercise the exact same browser →
  // router contract, including native WebSocket upgrades, rather than putting
  // Vite in the middle of the connection.
  const routerRuntimeConfig = {
    name: 'router-runtime-config',
    configureServer(server: { middlewares: { use: (path: string, handler: (request: unknown, response: { setHeader: (name: string, value: string) => void; end: (body: string) => void }) => void) => void } }) {
      if (!routerBase) return
      server.middlewares.use('/runtime-config.js', (_request, response) => {
        response.setHeader('Content-Type', 'application/javascript; charset=utf-8')
        response.end(`window.__RUNTIME_CONFIG__ = ${JSON.stringify({
          GATEWAY_API_URL: `${routerBase}/gateway`,
          AGENT_BRAIN_API_URL: `${routerBase}/brain`,
          ROUTER_BASE_URL: routerBase,
        })};`)
      })
    },
  }

  return {
    base,
    plugins: [react(), routerRuntimeConfig],
    server: {
      proxy: {
        '/connections': {
          target: devRouterTarget || 'http://localhost:8080',
          changeOrigin: true,
        },
        '/v1': {
          target: apiProxyTarget,
          changeOrigin: true,
          ...(useRouterProxy ? { rewrite: (path) => `/brain${path}` } : {}),
        },
        '/readyz': {
          target: apiProxyTarget,
          changeOrigin: true,
          ...(useRouterProxy ? { rewrite: (path) => `/brain${path}` } : {}),
        },
        '/healthz': {
          target: apiProxyTarget,
          changeOrigin: true,
          ...(useRouterProxy ? { rewrite: (path) => `/brain${path}` } : {}),
        },
        '/onboard': {
          target: devRouterTarget || 'http://localhost:8080',
          changeOrigin: true,
        },
        // Life Engine: the router owns identity and proxies /life to the
        // tenant's engine. Same target as /connections and /onboard.
        '/life': {
          target: devRouterTarget || 'http://localhost:8080',
          changeOrigin: true,
        },
        // Travel (maps-engine). In production the router serves /maps; in dev the engine is reached directly, and
        // MAPS_ENGINE_VERIFIED_USER acts as that user toward a port-forwarded tenant engine (which trusts the router's header).
        // Finance always uses the identity router. Preserve /finance for its routing and auth boundary.
        '/finance': {
          target: devRouterTarget || 'http://localhost:8080',
          changeOrigin: true,
        },
        '/maps': {
          target: process.env.MAPS_ENGINE_PROXY_TARGET || env.MAPS_ENGINE_PROXY_TARGET || 'http://127.0.0.1:8080',
          changeOrigin: true,
          rewrite: (path) => path.replace(/^\/maps/, ''),
          headers:
            process.env.MAPS_ENGINE_VERIFIED_USER || env.MAPS_ENGINE_VERIFIED_USER
              ? { 'X-Nighthawk-Verified-User': (process.env.MAPS_ENGINE_VERIFIED_USER || env.MAPS_ENGINE_VERIFIED_USER)! }
              : undefined,
        },
        // Prefix stripped to match nginx.conf.template's proxy_pass trailing
        // "/" behavior in production — the Gateway itself serves these
        // routes at its own root, not under /gateway.
        '/gateway': {
          target: gatewayProxyTarget,
          changeOrigin: true,
          ws: true,
          ...(useRouterProxy ? {} : { rewrite: (path) => path.replace(/^\/gateway/, '') }),
        },
      },
    },
  }
})
