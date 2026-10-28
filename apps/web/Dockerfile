# syntax=docker/dockerfile:1
# Build from the web app directory, which is the deployment builder's context:
#   docker build -t mission-control-web:local apps/web
# apps/web/package-lock.json is the app-scoped lock for this build; the root
# workspace lock remains the source for local development.
FROM docker.io/node:22-alpine AS build

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .

# Production defaults (override locally via --build-arg). Only Clerk key is set in CI (GitHub var).
ARG VITE_BASE_PATH=/
ARG VITE_API_BASE_URL=https://agent-memory.nighthawklabs.org
ARG VITE_MCP_SSE_URL=https://agent-memory.nighthawklabs.org/sse
ARG VITE_INSTALL_SCRIPT_URL=https://raw.githubusercontent.com/realnighthawk/agent-plugins/main/plugins/cursor/install.sh
ARG VITE_CLERK_PUBLISHABLE_KEY=
ARG VITE_GRAFANA_BASE_URL=
ARG VITE_GRAFANA_TRACE_URL=
# No absolute default the way VITE_API_BASE_URL has one above — the Gateway
# is deployed per-tenant (docs/components/gateway.md), not one shared global
# host, so empty (same-origin, via this image's own /gateway/ nginx proxy
# below) is the only default that makes sense across tenants.
ARG VITE_GATEWAY_BASE_URL=
# Travel (maps-engine, reached through the router with the Clerk token): the router's /maps. Empty derives it from
# VITE_GATEWAY_BASE_URL (".../gateway" -> ".../maps"), else same-origin "/maps". The Google Maps key is public by design
# (it ships in the bundle); restrict it by HTTP referrer in Google Cloud.
ARG VITE_MAPS_BASE_URL=
ARG VITE_GOOGLE_MAPS_API_KEY=

ENV VITE_BASE_PATH=$VITE_BASE_PATH \
    VITE_API_BASE_URL=$VITE_API_BASE_URL \
    VITE_CLERK_PUBLISHABLE_KEY=$VITE_CLERK_PUBLISHABLE_KEY \
    VITE_MCP_SSE_URL=$VITE_MCP_SSE_URL \
    VITE_INSTALL_SCRIPT_URL=$VITE_INSTALL_SCRIPT_URL \
    VITE_GRAFANA_BASE_URL=$VITE_GRAFANA_BASE_URL \
    VITE_GRAFANA_TRACE_URL=$VITE_GRAFANA_TRACE_URL \
    VITE_GATEWAY_BASE_URL=$VITE_GATEWAY_BASE_URL \
    VITE_MAPS_BASE_URL=$VITE_MAPS_BASE_URL \
    VITE_GOOGLE_MAPS_API_KEY=$VITE_GOOGLE_MAPS_API_KEY

RUN npm run build

FROM docker.io/nginx:1.27-alpine

RUN apk add --no-cache gettext

COPY docker/nginx.conf.template /etc/nginx/templates/default.conf.template
COPY docker/runtime-config.js.template /etc/nginx/templates/runtime-config.js.template
COPY docker/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

COPY --from=build /app/dist /usr/share/nginx/html

# 2026-09-24: AGENT_BRAIN_API_URL/GATEWAY_API_URL removed — nginx no longer
# proxies to either; ROUTER_PUBLIC_URL (rendered into runtime-config.js,
# read by src/lib/{gateway,api}.ts) replaces both. See docker-entrypoint.sh.
ENV ROUTER_PUBLIC_URL=http://host.docker.internal:8080 \
    NGINX_LISTEN_PORT=8080

EXPOSE 8080

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
