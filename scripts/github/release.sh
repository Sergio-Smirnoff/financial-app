#!/usr/bin/env bash
set -euo pipefail

OWNER="Sergio-Smirnoff"
declare -A REPO_MAP=(
  [ms-gateway]=financial-app-back-ms-gateway
  [ms-users]=financial-app-back-ms-users
  [ms-finances]=financial-app-back-ms-finances
  [ms-banks]=financial-app-back-ms-banks
  [ms-notifications]=financial-app-back-ms-notifications
  [ms-upload]=financial-app-back-ms-upload
  [ms-investments]=financial-app-back-ms-investments
  [front]=financial-app-front-financial-app
)

usage() {
  echo "usage: release.sh <major|minor|patch> <service...|all>"
  echo "services: ${!REPO_MAP[*]}"
  exit 1
}

BUMP=${1:-} && shift || usage
case "$BUMP" in major|minor|patch) ;; *) usage ;; esac
[[ $# -eq 0 ]] && usage
SERVICES=("$@")
[[ "${SERVICES[0]}" == "all" ]] && SERVICES=("${!REPO_MAP[@]}")

: "${GITHUB_TOKEN:?GITHUB_TOKEN env var required (workflow scope)}"

PAYLOAD=$(python3 -c "import json,sys; print(json.dumps({'ref': 'master', 'inputs': {'bump': sys.argv[1]}}))" "$BUMP")

for svc in "${SERVICES[@]}"; do
  repo=${REPO_MAP[$svc]:-}
  if [[ -z "$repo" ]]; then
    echo "unknown service: $svc" >&2
    exit 1
  fi
  curl -sS --fail-with-body -X POST \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$OWNER/$repo/actions/workflows/release.yml/dispatches" \
    -d "$PAYLOAD"
  echo "$svc: release ($BUMP) triggered"
done
