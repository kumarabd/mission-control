# agent-web Helm chart

MissionControl — the console for agent data (nginx + static SPA): Clerk login, workspace settings, and external system connections.

This is the standalone web chart distributed from the monorepo. The production deployment is the `agentWeb` template
inside `agent-harness/deploy/helm/agent-harness-shared`; that chart has no web dependency, so it is updated separately
by changing its `agentWeb.image.repository` value.

Requires agent-brain HTTP in-cluster or reachable from the browser (direct API mode).

## API modes

| `frontend.apiMode` | Browser calls | Helm / image |
|--------------------|---------------|--------------|
| `proxy` (default) | Same-origin `/v1` → nginx → `agentBrain.apiUrl` | Official image OK; leave `frontend.apiBaseUrl` empty |
| `direct` | Public agent-brain URL | Rebuild image with `image.buildArgs.viteApiBaseUrl`; set agent-brain `cors.allowedOrigins` |

## Install

**Proxy mode** (split agent-brain):

```bash
helm upgrade --install agent-web ./apps/web/charts/agent-web \
  --namespace agent-brain --create-namespace \
  --set image.tag=0.1.0 \
  --set agentBrain.apiUrl=http://agent-brain-memory-api:8080
```

**Minimal** (monolith):

```bash
helm upgrade --install agent-brain ./charts/agent-brain \
  -f charts/agent-brain/values-minimal.yaml \
  --namespace agent-brain --create-namespace

helm upgrade --install agent-web ./apps/web/charts/agent-web \
  -f apps/web/charts/agent-web/values-minimal.yaml \
  --namespace agent-brain
```

**Release image (GitHub tag `web-v*`):** set repository variable `VITE_CLERK_PUBLISHABLE_KEY=pk_live_...`.  
API/MCP/install URLs are **baked in `Dockerfile`** for `agent-memory.nighthawklabs.org`.

```bash
docker build -f apps/web/Dockerfile \
  --build-arg VITE_CLERK_PUBLISHABLE_KEY=pk_live_... \
  -t ghcr.io/kumarabd/mission-control-web:custom .
```

On agent-brain:

```yaml
cors:
  enabled: true
  allowedOrigins: "https://explorer.example.com"
explorer:
  clerkIssuer: "https://xxx.clerk.accounts.dev"
```

## Values

| Key | Description |
|-----|-------------|
| `image.*` | Container image (`ghcr.io/kumarabd/mission-control-web`; tag defaults to `Chart.appVersion`) |
| `image.buildArgs.*` | Vite build args for custom images (see `Dockerfile`) |
| `agentBrain.apiUrl` | nginx upstream for `/v1`, `/readyz`, `/healthz` (proxy mode) |
| `frontend.apiMode` | `proxy` or `direct` (documentation; direct needs custom image) |
| `frontend.apiBaseUrl` | Public agent-brain origin (`VITE_API_BASE_URL`) |
| `frontend.clerkPublishableKey` | Clerk (`VITE_CLERK_PUBLISHABLE_KEY`) |
| `frontend.mcpSseUrl` | Onboarding fallback MCP URL |
| `frontend.installScriptUrl` | Cursor install script fallback |
| `ingress.*` | Optional Ingress for Explorer host |

## agent-brain Service names

| agent-brain `architecture` | `agentBrain.apiUrl` |
|----------------------------|---------------------|
| `split` | `http://<release>-memory-api:8080` |
| `monolith` | `http://<release>-server:8080` |

Release `agent-brain` → `agent-brain-memory-api` or `agent-brain-server`.

## Port-forward

```bash
kubectl port-forward -n agent-brain svc/agent-web 3000:8080
open http://localhost:3000/onboarding
```

## Image build args

| Source | What |
|--------|------|
| **Dockerfile defaults** | `VITE_API_BASE_URL`, `VITE_MCP_SSE_URL`, `VITE_INSTALL_SCRIPT_URL`, `VITE_BASE_PATH` |
| **GitHub variable** | `VITE_CLERK_PUBLISHABLE_KEY` only (per repo/environment) |
| **Local override** | `docker build --build-arg VITE_*=...` for forks or staging |

Runtime Helm `AGENT_BRAIN_API_URL` is nginx proxy upstream only; the SPA uses baked `VITE_API_BASE_URL` for API calls.
