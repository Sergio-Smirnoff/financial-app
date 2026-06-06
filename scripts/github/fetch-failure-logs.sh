#!/usr/bin/env bash
set -euo pipefail

OWNER="Sergio-Smirnoff"
OUT_DIR="/tmp/ci-logs"

: "${GITHUB_TOKEN:?GITHUB_TOKEN env var required (Actions read scope)}"

mkdir -p "$OUT_DIR"

latest_logs_url() {
  local repo=$1 workflow=$2
  curl -sS "https://api.github.com/repos/$OWNER/$repo/actions/workflows/$workflow/runs?per_page=1" \
    | python3 -c "import json,sys; print(json.load(sys.stdin)['workflow_runs'][0]['logs_url'])"
}

fetch() {
  local repo=$1 workflow=$2 out=$3
  local url
  url=$(latest_logs_url "$repo" "$workflow")
  curl -sSL -H "Authorization: Bearer $GITHUB_TOKEN" -o "$OUT_DIR/$out" "$url"
  echo "saved $OUT_DIR/$out"
}

fetch financial-app-back-ms-users ci.yml ci-users.zip
fetch financial-app-back-ms-notifications ci.yml ci-notifications.zip
fetch financial-app-back-ms-investments ci.yml ci-investments.zip
fetch financial-app-back-ms-users docker-publish.yml publish-users.zip
fetch financial-app-back-ms-investments docker-publish.yml publish-investments.zip

ls -la "$OUT_DIR"
