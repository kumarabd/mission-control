# Web container image

Multi-stage Dockerfile at `apps/web/Dockerfile`: Node builds the Vite app from the npm workspace, then nginx serves
the SPA and proxies `/v1`, `/readyz`, `/healthz` to `AGENT_BRAIN_API_URL`.

## Local build

From the repository root, so `package.json` and `package-lock.json` describe the whole workspace:

```bash
docker build -f apps/web/Dockerfile -t mission-control-web:local .
docker run --rm -p 3000:8080 \
  -e AGENT_BRAIN_API_URL=http://host.docker.internal:8080 \
  mission-control-web:local
```

Or `docker compose up -d` from `apps/web`.

## Publish

The previous repository published `ghcr.io/<owner>/agent-web` on `v*` tags. Image publishing is intentionally not
wired into the monorepo yet: the target image coordinate (new package name vs. preserving the old one) is part of the
repository cutover. The Helm chart still pins the existing artifact until that lands.

Push to `main` runs the web lint, typecheck, test and build workflow (`.github/workflows/web.yml`); it does not publish
an image.
