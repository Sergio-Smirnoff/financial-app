#!/usr/bin/env bash
set -euo pipefail

OWNER="Sergio-Smirnoff"
REPOS=(
  financial-app-back-ms-gateway
  financial-app-back-ms-users
  financial-app-back-ms-finances
  financial-app-back-ms-banks
  financial-app-back-ms-notifications
  financial-app-back-ms-upload
  financial-app-back-ms-investments
  financial-app-back-financial-app-parent
  financial-app-front-financial-app
)
RULESET_DIR="$(cd "$(dirname "$0")/../../.github/rulesets" && pwd)"
API="https://api.github.com"
DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

: "${GITHUB_TOKEN:?GITHUB_TOKEN env var required (repo admin scope)}"

gh_api() {
  local method=$1 path=$2 data=${3:-}
  if [[ -n "$data" ]]; then
    curl -sS --fail-with-body -X "$method" \
      -H "Authorization: Bearer $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github+json" \
      "$API$path" -d "$data"
  else
    curl -sS --fail-with-body -X "$method" \
      -H "Authorization: Bearer $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github+json" \
      "$API$path"
  fi
}

for repo in "${REPOS[@]}"; do
  for file in "$RULESET_DIR"/*.json; do
    name=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['name'])" "$file")
    existing_id=$(gh_api GET "/repos/$OWNER/$repo/rulesets" \
      | python3 -c "import json,sys; rs=[r['id'] for r in json.load(sys.stdin) if r['name']==sys.argv[1]]; print(rs[0] if rs else '')" "$name")
    if $DRY_RUN; then
      if [[ -n "$existing_id" ]]; then
        echo "[dry-run] $repo: UPDATE ruleset '$name' (#$existing_id)"
      else
        echo "[dry-run] $repo: CREATE ruleset '$name'"
      fi
      continue
    fi
    if [[ -n "$existing_id" ]]; then
      gh_api PUT "/repos/$OWNER/$repo/rulesets/$existing_id" "@$file" >/dev/null
      echo "$repo: updated ruleset '$name' (#$existing_id)"
    else
      gh_api POST "/repos/$OWNER/$repo/rulesets" "@$file" >/dev/null
      echo "$repo: created ruleset '$name'"
    fi
  done
done
