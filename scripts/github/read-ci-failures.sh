#!/usr/bin/env bash
set -euo pipefail

OWNER="Sergio-Smirnoff"
WORKFLOW="${WORKFLOW:-ci.yml}"

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

usage() {
  echo "usage: WORKFLOW=ci.yml read-ci-failures.sh <service...|all>"
  echo "services: ${!REPO_MAP[*]}"
  exit 1
}

[[ $# -eq 0 ]] && usage
SERVICES=("$@")
[[ "${SERVICES[0]}" == "all" ]] && SERVICES=("${!REPO_MAP[@]}")

: "${GITHUB_TOKEN:?GITHUB_TOKEN env var required (Actions: read)}"
API="https://api.github.com"

gh_api() {
  curl -sS --fail-with-body \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" "$@"
}

for svc in "${SERVICES[@]}"; do
  repo=${REPO_MAP[$svc]:-}
  [[ -z "$repo" ]] && { echo "unknown service: $svc" >&2; exit 1; }

  echo "==================== $svc ($repo) ===================="

  run=$(gh_api "$API/repos/$OWNER/$repo/actions/workflows/$WORKFLOW/runs?event=${EVENT:-pull_request}&per_page=1")
  run_id=$(printf '%s' "$run" | python3 -c "import json,sys; r=json.load(sys.stdin)['workflow_runs']; print(r[0]['id'] if r else '')")
  conclusion=$(printf '%s' "$run" | python3 -c "import json,sys; r=json.load(sys.stdin)['workflow_runs']; print(r[0]['conclusion'] if r else '')")
  [[ -z "$run_id" ]] && { echo "  no $WORKFLOW runs"; continue; }
  echo "  run $run_id conclusion=$conclusion"

  jobs=$(gh_api "$API/repos/$OWNER/$repo/actions/runs/$run_id/jobs")
  # failed job ids + names
  mapfile -t failed < <(printf '%s' "$jobs" | python3 -c "
import json,sys
for j in json.load(sys.stdin)['jobs']:
    if j['conclusion'] not in ('success','neutral','skipped',None):
        steps=[s['name'] for s in j.get('steps',[]) if s.get('conclusion')=='failure']
        print(f\"{j['id']}\t{j['name']}\t{','.join(steps)}\")
")
  if [[ ${#failed[@]} -eq 0 ]]; then
    echo "  no failed jobs found (run may still be in progress)"
    continue
  fi

  for row in "${failed[@]}"; do
    job_id=${row%%$'\t'*}; rest=${row#*$'\t'}
    job_name=${rest%%$'\t'*}; failed_step=${rest#*$'\t'}
    echo "  --- job: $job_name | failed step: $failed_step ---"
    # plain-text log for the job, print error-relevant lines with context
    curl -sSL -H "Authorization: Bearer $GITHUB_TOKEN" \
      "$API/repos/$OWNER/$repo/actions/jobs/$job_id/logs" \
      | grep -niE 'error|fail|BUILD FAILURE|Caused by|Exception|Tests run|cannot|No such|denied|could not|rule violated|covered ratio|but expected minimum' \
      | tail -60 || echo "    (no matching lines)"
    echo
  done
done
