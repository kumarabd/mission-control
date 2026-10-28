#!/bin/sh
set -eu

# 2026-09-24: AGENT_BRAIN_API_URL/GATEWAY_API_URL removed — nginx no longer
# reverse-proxies to either (agent-harness/docs/components/gateway/web.md,
# "Resolved: Shared agent-web + Identity-Routing Router" — cutting the
# nginx-proxy hop in favor of the browser calling the router directly).
# ROUTER_PUBLIC_URL replaces both, consumed by runtime-config.js.template
# instead of nginx.conf.template.
: "${ROUTER_PUBLIC_URL:=http://127.0.0.1:8080}"
: "${NGINX_LISTEN_PORT:=8080}"

# Strip a trailing slash so runtime-config.js.template's "${ROUTER_PUBLIC_URL}/gateway"
# never renders a double slash.
export ROUTER_PUBLIC_URL="${ROUTER_PUBLIC_URL%/}"
export NGINX_LISTEN_PORT

envsubst '${NGINX_LISTEN_PORT}' \
  < /etc/nginx/templates/default.conf.template \
  > /etc/nginx/conf.d/default.conf

envsubst '${ROUTER_PUBLIC_URL}' \
  < /etc/nginx/templates/runtime-config.js.template \
  > /usr/share/nginx/html/runtime-config.js

exec "$@"
