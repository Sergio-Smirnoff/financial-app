#!/usr/bin/env bash
# =============================================================================
# release-manager.sh — Interactive promote + release for financial-app (polyrepo)
# =============================================================================
# Merges the old promote.sh + release.sh into one fzf/gum interactive tool with
# the same UX as git-manager.sh.
#
#   promote   develop -> master per repo: create/reuse PR, wait for checks, merge
#   release   dispatch the Release workflow (major|minor|patch) -> vX.Y.Z + images
#   status    show develop↑master ahead + latest release tag per repo
#
# Both promote and release run in PARALLEL across repos, EXCEPT the parent POM:
# it is always promoted FIRST and synchronously, because every backend service's
# CI checks out parent@master to resolve commons-* — services must not build
# against a stale parent.
#
# Requires: GITHUB_TOKEN (pull-requests:write + workflow), fzf, gum, curl, python3
# Usage: ./release-manager.sh [status|promote|release|help]   (no arg = menu)
# =============================================================================

set -euo pipefail

# ─── Config ─────────────────────────────────────────────────────────────────
OWNER="Sergio-Smirnoff"
API="https://api.github.com"
POLL_SECONDS=20
MAX_POLLS=45
PARENT_LABEL="parent"

# ─── Colors ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; DIM='\033[2m'; BOLD='\033[1m'; RESET='\033[0m'

# ─── Repository registry — "group:label:github-repo" (order = display + run) ──
REPOS=(
    "back:parent:financial-app-back-financial-app-parent"
    "back:ms-gateway:financial-app-back-ms-gateway"
    "back:ms-users:financial-app-back-ms-users"
    "back:ms-finances:financial-app-back-ms-finances"
    "back:ms-banks:financial-app-back-ms-banks"
    "back:ms-notifications:financial-app-back-ms-notifications"
    "back:ms-upload:financial-app-back-ms-upload"
    "back:ms-investments:financial-app-back-ms-investments"
    "front:front:financial-app-front-financial-app"
)

# ─── Helpers ────────────────────────────────────────────────────────────────
info()    { echo -e "${CYAN}${BOLD}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}${BOLD}  OK${RESET}    $*"; }
warn()    { echo -e "${YELLOW}${BOLD}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}${BOLD}[ERR]${RESET}   $*" >&2; }
header()  { echo -e "\n${BOLD}${BLUE}═══ $* ═══${RESET}\n"; }
divider() { echo -e "${DIM}$(printf '%.0s─' {1..60})${RESET}"; }

get_group() { echo "${1%%:*}"; }
get_label() { local rest="${1#*:}"; echo "${rest%%:*}"; }
get_repo()  { echo "${1##*:}"; }

label_to_repo() {
    local target="$1" r
    for r in "${REPOS[@]}"; do
        [ "$(get_label "$r")" = "$target" ] && { get_repo "$r"; return; }
    done
}
label_to_group() {
    local target="$1" r
    for r in "${REPOS[@]}"; do
        [ "$(get_label "$r")" = "$target" ] && { get_group "$r"; return; }
    done
}

require_token() {
    : "${GITHUB_TOKEN:?GITHUB_TOKEN env var required (pull-requests:write + workflow scope)}"
}
require_tools() {
    local t
    for t in fzf gum curl python3; do
        command -v "$t" >/dev/null 2>&1 || { error "missing required tool: $t"; exit 1; }
    done
}

gh_api() {
    local method=$1 path=$2 data=${3:-}
    if [ -n "$data" ]; then
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
json_field() { python3 -c "import json,sys; d=json.load(sys.stdin); print(d$1)"; }

# ─── Repo selector (fzf multi-select) ────────────────────────────────────────
select_repos() {
    local prompt="${1:-Select repositories}" only_releasable="${2:-}" labels=() r
    for r in "${REPOS[@]}"; do
        local label group
        label=$(get_label "$r"); group=$(get_group "$r")
        [ "$only_releasable" = "releasable" ] && [ "$label" = "$PARENT_LABEL" ] && continue
        labels+=("${label} [${group}]")
    done
    local selected
    selected=$(printf '%s\n' "${labels[@]}" | fzf --multi \
        --header="$prompt (TAB select · CTRL-A all · ENTER confirm)" \
        --prompt="repos> " --height=15 --reverse \
        --bind='ctrl-a:toggle-all' 2>/dev/null) || { echo ""; return; }
    echo "$selected" | sed 's/ \[.*//'
}

# ─── Single-repo selector (fzf, parent excluded) ─────────────────────────────
select_one_repo() {
    local prompt="${1:-Select a repository}" labels=() r
    for r in "${REPOS[@]}"; do
        local label
        label=$(get_label "$r")
        [ "$label" = "$PARENT_LABEL" ] && continue
        labels+=("$label")
    done
    printf '%s\n' "${labels[@]}" | fzf --header="$prompt" \
        --prompt="repo> " --height=15 --reverse 2>/dev/null || echo ""
}

# ─── PR check-run state for a head sha ───────────────────────────────────────
checks_state() {
    local repo=$1 sha=$2
    gh_api GET "/repos/$OWNER/$repo/commits/$sha/check-runs" | python3 -c "
import json, sys
runs = json.load(sys.stdin)['check_runs']
if not runs:
    print('pending')
elif any(r['conclusion'] not in ('success','neutral','skipped') and r['status']=='completed' for r in runs):
    print('failure')
elif all(r['status']=='completed' for r in runs):
    print('success')
else:
    print('pending')
"
}

# ─── Promote one repo (develop -> master). Echoes progress; returns 0/1. ─────
promote_one() {
    local label=$1 repo body ahead pr sha state i
    repo=$(label_to_repo "$label")

    if ! body=$(gh_api GET "/repos/$OWNER/$repo/compare/master...develop" 2>/dev/null); then
        echo "[$label] cannot compare branches"; return 1
    fi
    ahead=$(printf '%s' "$body" | json_field "['ahead_by']")
    if [ "$ahead" = "0" ]; then
        echo "[$label] develop has nothing to promote — already on master"; return 0
    fi

    body=$(gh_api GET "/repos/$OWNER/$repo/pulls?base=master&head=$OWNER:develop&state=open")
    pr=$(printf '%s' "$body" | python3 -c "import json,sys; p=json.load(sys.stdin); print(p[0]['number'] if p else '')")
    if [ -z "$pr" ]; then
        body=$(gh_api POST "/repos/$OWNER/$repo/pulls" \
            '{"title":"feat: promote develop to master","head":"develop","base":"master"}') \
            || { echo "[$label] failed to create PR"; return 1; }
        pr=$(printf '%s' "$body" | json_field "['number']")
        echo "[$label] created PR #$pr"
    else
        echo "[$label] reusing open PR #$pr"
    fi

    sha=$(gh_api GET "/repos/$OWNER/$repo/pulls/$pr" | json_field "['head']['sha']")
    state="pending"
    for ((i=0; i<MAX_POLLS; i++)); do
        state=$(checks_state "$repo" "$sha")
        case "$state" in
            success) break ;;
            failure) echo "[$label] PR #$pr checks FAILED"; return 1 ;;
            *) sleep "$POLL_SECONDS" ;;
        esac
    done
    [ "$state" = "success" ] || { echo "[$label] PR #$pr checks still pending after $((POLL_SECONDS*MAX_POLLS))s"; return 1; }

    if gh_api PUT "/repos/$OWNER/$repo/pulls/$pr/merge" '{"merge_method":"merge"}' >/dev/null; then
        echo "[$label] PR #$pr merged into master"; return 0
    fi
    echo "[$label] merge of PR #$pr rejected (ruleset?)"; return 1
}

# ─── Release one repo (dispatch Release workflow). Returns 0/1. ──────────────
release_one() {
    local label=$1 bump=$2 repo payload
    repo=$(label_to_repo "$label")
    payload=$(python3 -c "import json,sys; print(json.dumps({'ref':'master','inputs':{'bump':sys.argv[1]}}))" "$bump")
    if gh_api POST "/repos/$OWNER/$repo/actions/workflows/release.yml/dispatches" "$payload" >/dev/null; then
        echo "[$label] release ($bump) dispatched"; return 0
    fi
    echo "[$label] release dispatch FAILED"; return 1
}

# ─── Run a function over labels in PARALLEL, capturing per-repo logs ─────────
# usage: run_parallel <fn> [extra-arg] -- label1 label2 ...
run_parallel() {
    local fn=$1; shift
    local extra=""
    if [ "$1" != "--" ]; then extra="$1"; shift; fi
    shift # drop --
    local labels=("$@")
    [ ${#labels[@]} -eq 0 ] && { info "nothing to do"; return 0; }

    local -A pid_of log_of
    local label logf
    for label in "${labels[@]}"; do
        logf=$(mktemp)
        log_of[$label]=$logf
        if [ -n "$extra" ]; then
            ( "$fn" "$label" "$extra" ) >"$logf" 2>&1 &
        else
            ( "$fn" "$label" ) >"$logf" 2>&1 &
        fi
        pid_of[$label]=$!
    done

    info "launched ${#labels[@]} job(s) in parallel: ${labels[*]}"
    echo ""

    local fails=()
    for label in "${labels[@]}"; do
        if wait "${pid_of[$label]}"; then
            cat "${log_of[$label]}" | sed 's/^/  /'
        else
            cat "${log_of[$label]}" | sed 's/^/  /'
            fails+=("$label")
        fi
        rm -f "${log_of[$label]}"
    done

    echo ""
    if [ ${#fails[@]} -gt 0 ]; then
        error "failed: ${fails[*]}"
        return 1
    fi
    success "all succeeded: ${labels[*]}"
    return 0
}

# ─── Commands ────────────────────────────────────────────────────────────────
cmd_status() {
    header "Promote / Release Status"
    printf "  %-16s %-22s %s\n" "REPO" "develop vs master" "LATEST RELEASE"
    divider
    local r
    for r in "${REPOS[@]}"; do
        local label repo ahead tag cmp
        label=$(get_label "$r"); repo=$(get_repo "$r")
        cmp=$(gh_api GET "/repos/$OWNER/$repo/compare/master...develop" 2>/dev/null || echo "")
        if [ -n "$cmp" ]; then
            ahead=$(printf '%s' "$cmp" | json_field "['ahead_by']" 2>/dev/null || echo "?")
        else
            ahead="?"
        fi
        tag=$(gh_api GET "/repos/$OWNER/$repo/releases/latest" 2>/dev/null \
              | python3 -c "import json,sys
try: print(json.load(sys.stdin).get('tag_name','—'))
except Exception: print('—')" 2>/dev/null || echo "—")
        local ahead_disp
        if [ "$ahead" = "0" ]; then ahead_disp="${DIM}up to date${RESET}"
        elif [ "$ahead" = "?" ]; then ahead_disp="${DIM}?${RESET}"
        else ahead_disp="${YELLOW}↑${ahead} to promote${RESET}"; fi
        printf "  %-16s %-22b %s\n" "$label" "$ahead_disp" "$tag"
    done
    echo ""
}

cmd_promote() {
    require_token
    header "Promote develop → master"

    local selected
    selected=$(select_repos "Select repos to promote")
    [ -z "$selected" ] && { warn "no repos selected"; return; }

    local labels=()
    while IFS= read -r l; do [ -n "$l" ] && labels+=("$l"); done <<< "$selected"

    # Determine whether the parent gate is needed (any backend service selected)
    local needs_parent=false has_parent=false rest=() l
    for l in "${labels[@]}"; do
        [ "$l" = "$PARENT_LABEL" ] && { has_parent=true; continue; }
        [ "$(label_to_group "$l")" = "back" ] && needs_parent=true
        rest+=("$l")
    done

    echo -e "  ${BOLD}Selected:${RESET} ${labels[*]}"
    if $needs_parent || $has_parent; then
        echo -e "  ${BOLD}Order:${RESET} ${CYAN}${PARENT_LABEL} first (blocking)${RESET}, then parallel: ${rest[*]:-—}"
    else
        echo -e "  ${BOLD}Order:${RESET} parallel: ${rest[*]}"
    fi
    echo ""
    gum confirm "Proceed with promote?" || { warn "aborted"; return; }

    # 1) Parent first, synchronously — services build against parent@master.
    if $needs_parent || $has_parent; then
        header "Step 1 — promote ${PARENT_LABEL} (blocking gate)"
        if ! promote_one "$PARENT_LABEL" | sed 's/^/  /'; then
            error "parent promote failed — aborting before services (their CI needs parent@master)"
            return 1
        fi
    fi

    # 2) Everything else in parallel.
    if [ ${#rest[@]} -gt 0 ]; then
        header "Step 2 — promote ${#rest[@]} repo(s) in parallel"
        run_parallel promote_one -- "${rest[@]}" || true
    fi
}

cmd_release() {
    require_token
    header "Release (tag vX.Y.Z + images)"

    local bump
    bump=$(printf '%s\n' \
        "major  — X+1.0.0 (first release: v0.0.0 → v1.0.0)" \
        "minor  — x.Y+1.0" \
        "patch  — x.y.Z+1" \
        | fzf --header="Select version bump" --prompt="bump> " --height=6 --reverse 2>/dev/null) || return
    bump=$(echo "$bump" | awk '{print $1}')
    [ -z "$bump" ] && return

    local selected
    selected=$(select_repos "Select repos to release (parent excluded — no image)" releasable)
    [ -z "$selected" ] && { warn "no repos selected"; return; }

    local labels=() l
    while IFS= read -r l; do [ -n "$l" ] && labels+=("$l"); done <<< "$selected"

    echo -e "  ${BOLD}Bump:${RESET}  ${GREEN}${bump}${RESET}"
    echo -e "  ${BOLD}Repos:${RESET} ${labels[*]}"
    echo ""
    gum confirm "Dispatch release ($bump) for ${#labels[@]} repo(s)?" || { warn "aborted"; return; }

    header "Dispatching releases in parallel"
    run_parallel release_one "$bump" -- "${labels[@]}" || true
    echo ""
    info "release workflows dispatched — watch each repo's Actions tab for the vX.Y.Z tag + image push"
}

# ─── Best-effort GHCR image-version cleanup for deleted tags ──────────────────
# usage: ghcr_cleanup <github-repo> <tag...>   (skips versions tagged 'latest')
ghcr_cleanup() {
    local pkg=$1; shift
    local targets=() t v
    for t in "$@"; do
        v="${t#v}"            # v1.1.0 -> 1.1.0
        targets+=("$v")
        targets+=("${v%.*}")  # 1.1.0 -> 1.1
    done

    local versions
    versions=$(gh_api GET "/users/$OWNER/packages/container/$pkg/versions?per_page=100" 2>/dev/null) || {
        warn "cannot list GHCR versions (token needs read:packages, or package is org-owned) — delete in the UI"
        return 0
    }

    local to_delete
    to_delete=$(printf '%s' "$versions" | python3 -c "
import json, sys
targets = set(sys.argv[1:])
for v in json.load(sys.stdin):
    tags = set(v.get('metadata', {}).get('container', {}).get('tags', []))
    if not tags or 'latest' in tags:   # never nuke the digest that holds :latest
        continue
    if tags & targets:
        print(str(v['id']) + '\t' + ','.join(sorted(tags)))
" "${targets[@]}" 2>/dev/null || echo "")

    if [ -z "$to_delete" ]; then
        info "no matching GHCR versions to delete (or they share the :latest digest — skipped)"
        return 0
    fi

    local id tags
    while IFS=$'\t' read -r id tags; do
        [ -z "$id" ] && continue
        if gh_api DELETE "/users/$OWNER/packages/container/$pkg/versions/$id" >/dev/null 2>&1; then
            success "GHCR version deleted [$tags]"
        else
            error "GHCR version $id delete failed (token needs delete:packages) — [$tags]"
        fi
    done <<< "$to_delete"
}

cmd_revert() {
    require_token
    header "Revert a release (delete GitHub release + git tag)"

    local label repo
    label=$(select_one_repo "Select repo to revert a release in")
    [ -z "$label" ] && { warn "no repo selected"; return; }
    repo=$(label_to_repo "$label")

    local tags
    tags=$(gh_api GET "/repos/$OWNER/$repo/tags?per_page=100" 2>/dev/null \
        | python3 -c "import json,sys
for t in json.load(sys.stdin): print(t['name'])" 2>/dev/null || echo "")
    if [ -z "$tags" ]; then
        info "$label has no tags — nothing to revert"; return
    fi

    local selected
    selected=$(printf '%s\n' "$tags" | fzf --multi \
        --header="$label — select tag(s) to DELETE (release + tag) · TAB select · CTRL-A all · ENTER confirm" \
        --prompt="tag> " --height=15 --reverse \
        --bind='ctrl-a:toggle-all' 2>/dev/null) || return
    [ -z "$selected" ] && { warn "no tags selected"; return; }

    local tag_list=() t
    while IFS= read -r t; do [ -n "$t" ] && tag_list+=("$t"); done <<< "$selected"

    echo ""
    echo -e "  ${BOLD}Repo:${RESET}   $label"
    echo -e "  ${BOLD}Delete:${RESET} ${RED}${tag_list[*]}${RESET}"
    echo -e "  ${DIM}removes the GitHub Release + git tag for each${RESET}"
    echo ""
    gum confirm "Delete ${#tag_list[@]} release(s)+tag(s) in $label?" --default=false || { warn "aborted"; return; }
    echo ""

    local tag rel_id
    for tag in "${tag_list[@]}"; do
        rel_id=$(gh_api GET "/repos/$OWNER/$repo/releases/tags/$tag" 2>/dev/null | json_field "['id']" 2>/dev/null || echo "")
        if [ -n "$rel_id" ]; then
            if gh_api DELETE "/repos/$OWNER/$repo/releases/$rel_id" >/dev/null 2>&1; then
                success "$tag: release deleted"
            else
                error "$tag: release delete failed"
            fi
        else
            info "$tag: no GitHub release (tag-only)"
        fi
        if gh_api DELETE "/repos/$OWNER/$repo/git/refs/tags/$tag" >/dev/null 2>&1; then
            success "$tag: tag deleted"
        else
            error "$tag: tag delete failed (token needs contents:write)"
        fi
    done

    echo ""
    if gum confirm "Also delete matching GHCR image versions for $label?" --default=false; then
        ghcr_cleanup "$repo" "${tag_list[@]}"
    else
        echo -e "  ${DIM}Skipped GHCR — :latest self-corrects on next release; delete image tags in the UI if needed.${RESET}"
    fi

    echo ""
    info "Re-release with the correct bump to recompute the version:"
    echo -e "    ${CYAN}release-manager.sh${RESET} → release → <bump> → $label"
    echo -e "  ${DIM}(release.yml computes from the latest remaining v* tag; none left → v0.0.0)${RESET}"
}

cmd_help() {
    echo -e "${BOLD}release-manager.sh${RESET} — interactive promote + release (polyrepo)"
    echo ""
    echo -e "  ${BOLD}Usage:${RESET} ./release-manager.sh [command]"
    echo ""
    echo -e "  ${BOLD}Commands:${RESET}"
    echo "    status     develop↑master ahead + latest release tag per repo"
    echo "    promote    develop → master (parent first, then parallel)"
    echo "    release    dispatch Release workflow (major|minor|patch), parallel"
    echo "    revert     delete a release + tag (and optional GHCR image), then re-release"
    echo "    help       this help"
    echo ""
    echo -e "  ${BOLD}Interactive:${RESET} run without arguments for the menu"
    echo -e "  ${BOLD}Env:${RESET} GITHUB_TOKEN (pull-requests:write + workflow)"
    echo ""
    echo -e "  ${DIM}Parent is always promoted FIRST and blocking — backend service CI"
    echo -e "  checks out parent@master to resolve commons-*.${RESET}"
}

# ─── Interactive menu ────────────────────────────────────────────────────────
interactive_menu() {
    while true; do
        local choice cmd
        choice=$(printf '%s\n' \
            "status   — ahead + latest tag per repo" \
            "promote  — develop → master (parent first, then parallel)" \
            "release  — dispatch Release workflow (parallel)" \
            "revert   — delete a release + tag (and optional image)" \
            "exit     — quit" \
            | fzf --header="Release Manager — select action" \
                  --prompt="action> " --height=12 --reverse 2>/dev/null) || break
        cmd=$(echo "$choice" | awk '{print $1}')
        case "$cmd" in
            exit) break ;;
            status|promote|release|revert) "cmd_$cmd" ;;
            *) error "unknown action" ;;
        esac
        echo ""
        read -rp "Press ENTER to continue..." _
    done
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    require_tools
    if [ $# -eq 0 ]; then
        interactive_menu
    else
        case "$1" in
            status|promote|release|revert|help) "cmd_$1" ;;
            *) error "unknown command: $1"; cmd_help; exit 1 ;;
        esac
    fi
}

main "$@"
