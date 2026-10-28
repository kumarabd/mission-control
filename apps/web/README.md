# Mission Control · web

Mission Control is the web home for creating and managing personal AI assistants and companions. The public landing page demonstrates the platform through animated daily-life scenes, context and privacy controls, and a local companion preview; signed-in users can chat, manage their workspace, inspect memory and activity, and use connected tools.

The platform brings together agent-harness (execution and workspace services), [agent-brain](https://github.com/realnighthawk/agent-brain) (memory), and life-engine (personal records). The web app connects through the shared router; direct agent-brain explorer access remains available for development. In production, nginx serves the SPA and configured API routes. See [PRODUCT.md](PRODUCT.md) for positioning and capability boundaries.

## Local development

The web app is an npm workspace in the Mission Control monorepo. Run these from the repository root (or from `apps/web` with `npm run dev` in the workspace).

The public landing page and its fictional examples run without a backend. For direct explorer development, run the agent-brain API on `http://localhost:8080` (see its README). Connected features require the corresponding backend services and authentication configuration.

```bash
npm install
cp apps/web/.env.example apps/web/.env
npm run dev
```

Open [http://localhost:5173](http://localhost:5173). Vite proxies `/v1`, `/readyz`, and `/healthz` to the API host.

If agent-brain is not on port 8080:

```bash
AGENT_BRAIN_API_URL=http://localhost:8899 npm run dev
# or: VITE_DEV_API_PROXY=http://localhost:8899 npm run dev
```

Restart `npm run dev` after changing the port (Vite reads proxy target at startup).

### Router-backed development

Production routes requests through the shared router. When you forward that
service locally, use router mode rather than the direct agent-brain proxy:

```bash
VITE_DEV_ROUTER_PROXY=http://localhost:3001 npm run dev
```

Vite serves the same runtime configuration used in production: the browser
calls the router directly at `/brain`, `/gateway`, `/connections`, and
`/onboard`. This includes the chat WebSocket, so Vite is not an extra proxy
hop. The router must allow `http://localhost:5173` in its CORS configuration.

Auth: configured deployments use Clerk sign-in and workspace setup. Legacy direct-explorer mode accepts an API key or JWT in the UI (stored in `localStorage`) and uses the agent-brain headers (`X-API-Key`, `Authorization: Bearer`, `X-Agent-Id`).

## Build

```bash
npm run build
```

Artifacts land in `apps/web/dist/`. For a subpath deploy (legacy `/explorer/`), set `VITE_BASE_PATH=/explorer/` at build time.

## Docker

The image build uses `apps/web` as its context and the app-scoped `apps/web/package-lock.json`:

```bash
# from the repository root
docker build -t mission-control-web:local apps/web
docker run --rm -p 3000:8080 \
  -e AGENT_BRAIN_API_URL=http://host.docker.internal:8080 \
  mission-control-web:local
```

Or from `apps/web`:

```bash
docker compose up -d
# UI: http://localhost:3000
```

Environment:

| Variable | Default | Description |
|----------|---------|-------------|
| `AGENT_BRAIN_API_URL` | `http://host.docker.internal:8080` | Upstream agent-brain HTTP API |
| `NGINX_LISTEN_PORT` | `8080` | Container listen port |

## CI / publish

The web checks run from the repository root in `.github/workflows/web.yml` on pushes and pull requests that touch
`apps/web/**` or the root lockfile: lint, typecheck, tests and build.

The standalone Helm chart publishes from `.github/workflows/web-chart.yml` on `web-v*` tags:

```bash
git tag web-v0.1.0
git push origin web-v0.1.0
```

Container images are **not** published from this repository. Build and push `apps/web/Dockerfile` in the deployment
pipeline; the shared agent-harness deployment uses the `internal` tag. The Helm chart defaults its image tag to
`Chart.appVersion` (currently `0.1.0`).

## Kubernetes (Helm)

From the repository root:

```bash
helm upgrade --install agent-web ./apps/web/charts/agent-web \
  -f apps/web/charts/agent-web/values-minimal.yaml \
  --namespace agent-brain --create-namespace
```

See [charts/agent-web/README.md](charts/agent-web/README.md). Pair with agent-brain `values-minimal.yaml` for a single-namespace demo.

## Repository layout

| Path | Purpose |
|------|---------|
| `src/` | React SPA (Vite + TypeScript + Tailwind) |
| `docs/` | Public product documentation (served at `/docs`) |
| `charts/agent-web/` | Helm chart |
| `docker/` | nginx template and entrypoint |
| `Dockerfile` | Multi-stage build (Node → nginx), built from the repo root |
| `docker-compose.yml` | Local UI container |

## Finance

The Finance page at `/finance` shows canonical spending records, per-currency net totals, category breakdowns, and monthly spending. Filter by date, merchant/note search, currency, category, tag, or type; expand a record for its splits and tags, paginate results, or export the complete filtered selection as CSV. Refunds reduce spending on their own date and transfers are excluded from totals. Aggregate amounts retain exact minor-unit precision.

Every request is a Clerk-authenticated POST to `<router>/finance/api/v1/operations/<name>`. The page uses `spends_search`, `spending_analyze`, directory list operations, and `spends_export`; it does not read the legacy account/transaction tables. Query caches are scoped to the Clerk user and discarded when unused. No direct engine endpoint or trusted identity headers are used by the browser.

The router base resolves from runtime `ROUTER_BASE_URL`, then `VITE_ROUTER_BASE_URL`, then the router inferred from `VITE_GATEWAY_BASE_URL` (ending in `/gateway`), else same-origin `/finance`. For development set `VITE_DEV_ROUTER_PROXY` to the router address. The same-origin Vite `/finance` proxy also targets that router, preserving the prefix; its fallback is a local router at `http://localhost:8080`.

Deployment requires the router's `/finance/` route, an enabled tenant finance engine, router CORS allowing the web origin, and that same origin in the engine's `TRUSTED_ORIGINS` (`financeEngine.trustedOrigins` in the tenant chart). The browser's bearer token is verified by the router, which supplies the private engine identity headers.

## Travel

The **Travel** section (Plan, Fleet, Trips) is the former maps-web, now part of Mission Control. It talks to the signed-in
user's own maps-engine through the router (`<router>/maps/api/v1`) with their Clerk session token.

Build-time settings: `VITE_GOOGLE_MAPS_API_KEY` (Maps JavaScript API; public, restrict it by HTTP referrer) and, optionally,
`VITE_MAPS_BASE_URL` (defaults to the router implied by `VITE_GATEWAY_BASE_URL`, else same-origin `/maps`).

Local development: `MAPS_ENGINE_PROXY_TARGET=http://127.0.0.1:8080 npm run dev` proxies `/maps` to an engine directly
(`MAPS_ENGINE_VERIFIED_USER` acts as that user toward a port-forwarded tenant engine). The code lives in `src/travel/`.
