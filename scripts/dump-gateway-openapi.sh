#!/usr/bin/env bash
# Dumps ms-gateway's OpenAPI document into the front repo as the BFF contract snapshot.
set -euo pipefail

OUT="${1:-front/financial-app/openapi/gateway.json}"
URL="${GATEWAY_URL:-http://localhost:8080}/v3/api-docs"

if ! curl -sf "${URL}" -o /tmp/gateway-openapi.json; then
  echo "cannot reach ${URL} — start it with: docker compose --profile app up -d gateway" >&2
  exit 1
fi

mkdir -p "$(dirname "${OUT}")"
jq -S . /tmp/gateway-openapi.json > "${OUT}"
echo "wrote ${OUT} ($(jq '.components.schemas | length' "${OUT}") schemas)"
