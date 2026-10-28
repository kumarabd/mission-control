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

Push a `web-v*` tag to publish `ghcr.io/kumarabd/mission-control-web` through `.github/workflows/web-image.yml`:

```bash
git tag web-v0.1.0
git push origin web-v0.1.0
```

The workflow publishes the semver tag, the commit SHA and `latest` for `linux/amd64` and `linux/arm64`. Set the
repository variable `VITE_CLERK_PUBLISHABLE_KEY` before releasing. The Helm chart defaults to `Chart.appVersion`
(`0.1.0`), which matches the first release tag. `workflow_dispatch` publishes a SHA and `latest` build without a
semver tag.

Push to `main` runs the web lint, typecheck, test and build workflow (`.github/workflows/web.yml`); it does not publish
an image.
