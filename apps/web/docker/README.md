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

Container images are not published from this repository. Build and push the image in the deployment pipeline. The
shared agent-harness chart expects `ghcr.io/kumarabd/mission-control-web:internal` (or the tag set in its values).

Push to `main` runs the web lint, typecheck, test and build workflow (`.github/workflows/web.yml`); it does not publish
an image. The standalone Helm chart is published separately by `.github/workflows/web-chart.yml` on `web-v*` tags.
