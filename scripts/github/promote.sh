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
  [parent]=financial-app-back-financial-app-parent
  [front]=financial-app-front-financial-app
)
API="https://api.github.com"
POLL_SECONDS=20
MAX_POLLS=45

usage() {
  echo "usage: promote.sh <service...|all>"
  echo "services: ${!REPO_MAP[*]}"
  exit 1
}

[[ $# -eq 0 ]] && usage
SERVICES=("$@")
[[ "${SERVICES[0]}" == "all" ]] && SERVICES=("${!REPO_MAP[@]}")

: "${GITHUB_TOKEN:?GITHUB_TOKEN env var required (pull requests: write)}"

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

json_field() {
  python3 -c "import json,sys; d=json.load(sys.stdin); print(d$1)"
}

FAILURES=()

promote() {
  local svc=$1 repo=$2 pr_number pr_state body

  if ! body=$(gh_api GET "/repos/$OWNER/$repo/compare/master...develop"); then
    echo "$svc: cannot compare branches" >&2
    return 1
  fi
  if [[ $(printf '%s' "$body" | json_field "['ahead_by']") == "0" ]]; then
    echo "$svc: develop has nothing to promote, skipping"
    return 0
  fi

  body=$(gh_api GET "/repos/$OWNER/$repo/pulls?base=master&head=$OWNER:develop&state=open")
  pr_number=$(printf '%s' "$body" | python3 -c "import json,sys; prs=json.load(sys.stdin); print(prs[0]['number'] if prs else '')")

  if [[ -z "$pr_number" ]]; then
    body=$(gh_api POST "/repos/$OWNER/$repo/pulls" \
      '{"title":"chore: promote develop to master","head":"develop","base":"master"}') || {
      echo "$svc: failed to create PR" >&2
      return 1
    }
    pr_number=$(printf '%s' "$body" | json_field "['number']")
    echo "$svc: created PR #$pr_number"
  else
    echo "$svc: reusing open PR #$pr_number"
  fi

  local i sha state
  sha=$(gh_api GET "/repos/$OWNER/$repo/pulls/$pr_number" | json_field "['head']['sha']")
  for ((i = 0; i < MAX_POLLS; i++)); do
    state=$(gh_api GET "/repos/$OWNER/$repo/commits/$sha/check-runs" \
      | python3 -c "
import json, sys
runs = json.load(sys.stdin)['check_runs']
if not runs:
    print('pending')
elif any(r['conclusion'] not in ('success', 'neutral', 'skipped') and r['status'] == 'completed' for r in runs):
    print('failure')
elif all(r['status'] == 'completed' for r in runs):
    print('success')
else:
    print('pending')
")
    case "$state" in
      success) break ;;
      failure)
        echo "$svc: PR #$pr_number checks FAILED — fix and re-run" >&2
        return 1
        ;;
      *) sleep "$POLL_SECONDS" ;;
    esac
  done
  if [[ "$state" != "success" ]]; then
    echo "$svc: PR #$pr_number checks still pending after $((POLL_SECONDS * MAX_POLLS))s" >&2
    return 1
  fi

  if gh_api PUT "/repos/$OWNER/$repo/pulls/$pr_number/merge" '{"merge_method":"merge"}' >/dev/null; then
    echo "$svc: PR #$pr_number merged into master"
  else
    echo "$svc: merge of PR #$pr_number rejected (rules not satisfied?)" >&2
    return 1
  fi
}

for svc in "${SERVICES[@]}"; do
  repo=${REPO_MAP[$svc]:-}
  if [[ -z "$repo" ]]; then
    echo "unknown service: $svc" >&2
    exit 1
  fi
  promote "$svc" "$repo" || FAILURES+=("$svc")
done

if (( ${#FAILURES[@]} )); then
  echo "FAILED: ${FAILURES[*]}" >&2
  exit 1
fi
