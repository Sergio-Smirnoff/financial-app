#!/usr/bin/env bash
# Records live BFF responses as frontend test fixtures. Requires seed-demo-user.sh first.
set -euo pipefail

GW="${GATEWAY_URL:-http://localhost:8080}"
JAR=/tmp/demo-cookies.txt
OUT="${1:-front/financial-app/lib/api/bff/__fixtures__}"
mkdir -p "$OUT"

grab() { # grab <fixture-name> <path-with-query>
  curl -sf -b "$JAR" "$GW$2" | jq -S '.data' > "$OUT/$1.json"
  printf '  %-20s %s\n' "$1.json" "$(jq -r 'keys | join(", ")' "$OUT/$1.json")"
}

grab overview     "/api/v1/bff/overview?currency=ARS&secondary=none"
grab banks        "/api/v1/bff/banks?currency=ARS&secondary=none"
grab transactions "/api/v1/bff/transactions?currency=ARS&secondary=none&page=0&size=20"
grab categories   "/api/v1/bff/categories?currency=ARS&secondary=none"
grab investments  "/api/v1/bff/investments?currency=ARS&secondary=none"
grab imports      "/api/v1/bff/imports"
grab settings     "/api/v1/bff/settings"
grab search       "/api/v1/bff/search?q=Coto"

TX_ID=$(jq -r '.page.data.rows[0].id' "$OUT/transactions.json")
grab transaction-detail "/api/v1/bff/transactions/$TX_ID?currency=ARS&secondary=none"
