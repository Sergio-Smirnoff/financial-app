#!/usr/bin/env bash
# Executable form of the P1 goals G2-G6.
# Usage: scripts/ai-verify.sh
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

GREP=/usr/bin/grep
fail=0
pass() { printf 'ok    %s\n' "$1"; }
bad()  { printf 'FAIL  %s\n' "$1"; fail=1; }

# --- G3: line caps -----------------------------------------------------------
check_cap() {
  local file="$1" cap="$2" n
  if [[ ! -f "$file" ]]; then bad "G3 $file missing"; return; fi
  n=$(wc -l < "$file")
  if (( n <= cap )); then pass "G3 $file $n/$cap lines"
  else bad "G3 $file $n lines exceeds cap $cap"; fi
}

# --- G2: no references to deleted paths --------------------------------------
# back/ and front/ are excluded here and covered precisely by p2g2 (their .ai/ and README).
g2() {
  local hits
  hits=$($GREP -rl \
    -e 'docs/specs/rules' -e 'docs/specs/workflow' -e 'docs/specs/architecture' \
    -e 'docs/specs/deployment' -e 'docs/specs/00-master' . \
    --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=back \
    --exclude-dir=front --exclude-dir=.superpowers 2>/dev/null \
    | $GREP -v 'ai-restructure' | $GREP -v 'ai-verify.sh' \
    | $GREP -v 'superpowers' | $GREP -v '_migration-coverage' || true)
  if [[ -z "$hits" ]]; then pass "G2 no references to deleted spec paths"
  else bad "G2 stale references in:"; printf '        %s\n' $hits; fi
}

# --- G4/G5: links resolve, entry point is coherent ---------------------------
g4() {
  bash scripts/ai-link.sh --check >/dev/null 2>&1 \
    && pass "G4 all symlinks correct" || bad "G4 ai-link.sh --check failed"
  local f
  for f in CLAUDE.md AGENTS.md GEMINI.md; do
    if [[ "$(readlink -f "$f" 2>/dev/null)" == "$ROOT/.ai/AGENTS.md" ]]; then
      pass "G4 $f resolves to .ai/AGENTS.md"
    else bad "G4 $f does not resolve to .ai/AGENTS.md"; fi
  done
  [[ -f "$(readlink -f .mcp.json 2>/dev/null)" ]] \
    && pass "G4 .mcp.json resolves to a real file" || bad "G4 .mcp.json dangles"
}

g5() {
  [[ -f .ai/AGENTS.md ]] || { bad "G5 .ai/AGENTS.md missing"; return; }
  local n; n=$($GREP -c '^@' .ai/AGENTS.md || true)
  (( n == 4 )) && pass "G5 AGENTS.md declares exactly 4 @-imports" \
                || bad "G5 AGENTS.md has $n @-imports, expected 4"
  local missing=0 p
  while read -r p; do
    [[ -z "$p" ]] && continue
    [[ -e "${p#@}" ]] || { printf '        unresolved: %s\n' "$p"; missing=1; }
  done < <($GREP -ho '^@[^ ]*' .ai/AGENTS.md || true)
  while read -r p; do
    [[ -z "$p" ]] && continue
    [[ "$p" == http* ]] && continue
    [[ -e "$p" ]] || { printf '        unresolved link: %s\n' "$p"; missing=1; }
  done < <($GREP -hoE '\]\((\.ai|docs|scripts)/[^)]*\)' .ai/AGENTS.md .ai/references/*.md 2>/dev/null \
            | sed 's/^](//; s/)$//' || true)
  (( missing == 0 )) && pass "G5 all referenced paths resolve" \
                     || bad "G5 unresolved paths above"
}

# --- G6: no rule id defined twice --------------------------------------------
g6() {
  [[ -f .ai/references/RULES.md ]] || { bad "G6 RULES.md missing"; return; }
  local dupes
  dupes=$($GREP -rhoE '^### R[0-9]+' .ai/ | sort | uniq -d || true)
  [[ -z "$dupes" ]] && pass "G6 no duplicate rule ids" \
                    || bad "G6 duplicate rule ids: $dupes"
}

P2_REPOS=(
  "back/financial-app-parent" "back/ms-banks" "back/ms-finances" "back/ms-gateway"
  "back/ms-investments" "back/ms-notifications" "back/ms-upload" "back/ms-users"
  "front/financial-app"
)

# --- P2-G1: every repo has an .ai/ tree with the expected references ---------
p2g1() {
  local repo refs r missing=0
  for repo in "${P2_REPOS[@]}"; do
    case "$repo" in
      front/financial-app)        refs="ROUTES.md API_CLIENT.md UI_STATE.md" ;;
      back/financial-app-parent)  refs="COMMONS.md" ;;
      *)                          refs="DOMAIN.md API.md EVENTS.md" ;;
    esac
    [[ -f "$repo/.ai/AGENTS.md" ]] || { printf '        missing %s\n' "$repo/.ai/AGENTS.md"; missing=1; }
    for r in $refs; do
      [[ -f "$repo/.ai/references/$r" ]] || { printf '        missing %s\n' "$repo/.ai/references/$r"; missing=1; }
    done
  done
  (( missing == 0 )) && pass "P2-G1 all nine repos carry .ai/ trees" \
                     || bad "P2-G1 missing repo context files above"
}

# --- P2-G2: no repo file references a spec P1 deleted ------------------------
p2g2() {
  local hits repo
  hits=""
  for repo in "${P2_REPOS[@]}"; do
    hits+="$($GREP -rl -e 'docs/specs/rules' -e 'docs/specs/workflow' \
      -e 'docs/specs/00-master' -e 'docs/specs/architecture' -e 'docs/specs/deployment' \
      "$repo/.ai" "$repo/README.md" 2>/dev/null || true)"
  done
  [[ -z "$hits" ]] && pass "P2-G2 no repo references a deleted spec" \
                   || { bad "P2-G2 stale references in:"; printf '        %s\n' $hits; }
}

# --- P2-G3: repo line caps ---------------------------------------------------
p2g3() {
  local repo
  for repo in "${P2_REPOS[@]}"; do
    check_cap "$repo/.ai/AGENTS.md" 70
  done
  for repo in back/ms-banks back/ms-finances back/ms-gateway back/ms-investments \
              back/ms-notifications back/ms-upload back/ms-users; do
    check_cap "$repo/.ai/references/DOMAIN.md" 180
    check_cap "$repo/.ai/references/API.md"    120
    check_cap "$repo/.ai/references/EVENTS.md"  60
  done
  check_cap front/financial-app/.ai/references/ROUTES.md      120
  check_cap front/financial-app/.ai/references/API_CLIENT.md  100
  check_cap front/financial-app/.ai/references/UI_STATE.md     80
  check_cap back/financial-app-parent/.ai/references/COMMONS.md 120
  check_cap .ai/services/MAP.md       40
  check_cap .ai/services/EXTERNAL.md  80
}

# --- P2-G4: every relative path named in a repo .ai/ file resolves -----------
p2g4() {
  local repo f p missing=0 base
  for repo in "${P2_REPOS[@]}"; do
    [[ -d "$repo/.ai" ]] || continue
    while read -r f; do
      base="$(dirname "$f")"
      while read -r p; do
        [[ -z "$p" ]] && continue
        [[ "$p" == http* ]] && continue
        if [[ "$p" == .ai/* || "$p" == docs/* || "$p" == scripts/* ]]; then
          [[ -e "$p" ]] || { printf '        %s -> %s\n' "$f" "$p"; missing=1; }
        else
          [[ -e "$base/$p" || -e "$repo/$p" ]] || { printf '        %s -> %s\n' "$f" "$p"; missing=1; }
        fi
      done < <($GREP -hoE '\]\([^)h][^)]*\)' "$f" | sed 's/^](//; s/)$//' || true)
    done < <(find "$repo/.ai" -name '*.md')
  done
  (( missing == 0 )) && pass "P2-G4 all repo .ai/ paths resolve" \
                     || bad "P2-G4 unresolved paths above"
}

# --- P2-G5: repo symlinks are correct and untracked --------------------------
p2g5() {
  local repo name bad_link=0 tracked
  for repo in "${P2_REPOS[@]}"; do
    [[ -f "$repo/.ai/AGENTS.md" ]] || continue
    for name in CLAUDE.md AGENTS.md GEMINI.md; do
      [[ "$(readlink "$repo/$name" 2>/dev/null)" == ".ai/AGENTS.md" ]] \
        || { printf '        %s/%s wrong or missing\n' "$repo" "$name"; bad_link=1; }
      tracked="$(git -C "$repo" ls-files "$name" 2>/dev/null || true)"
      [[ -z "$tracked" ]] || { printf '        %s/%s still tracked\n' "$repo" "$name"; bad_link=1; }
    done
  done
  (( bad_link == 0 )) && pass "P2-G5 repo links correct and untracked" \
                      || bad "P2-G5 link problems above"
}

# --- P2-G6: coverage matrix has no unverified row ---------------------------
p2g6() {
  local f=.ai/_migration-coverage-p2.md
  [[ -f "$f" ]] || { bad "P2-G6 $f missing"; return; }
  local open; open=$($GREP -c '| *no *|' "$f" || true)
  (( open == 0 )) && pass "P2-G6 migration coverage complete" \
                  || bad "P2-G6 $open unverified rows in $f"
}

# --- P2-G7: repo diffs touch only agent context ------------------------------
p2g7() {
  local repo files offenders=0
  for repo in "${P2_REPOS[@]}"; do
    files="$(git -C "$repo" diff --name-only HEAD~1..HEAD 2>/dev/null || true)"
    while read -r f; do
      [[ -z "$f" ]] && continue
      case "$f" in
        .ai/*|.gitignore|README.md|CLAUDE.md|AGENTS.md|GEMINI.md) ;;
        *) printf '        %s: %s\n' "$repo" "$f"; offenders=1 ;;
      esac
    done <<< "$files"
  done
  (( offenders == 0 )) && pass "P2-G7 repo diffs touch only agent context" \
                       || bad "P2-G7 out-of-scope files above"
}

g2
g4
g5
check_cap .ai/AGENTS.md               120
check_cap .ai/references/RULES.md     150
check_cap .ai/references/ARCHITECTURE.md 120
check_cap .ai/references/WORKFLOW.md  100
check_cap .ai/references/TECH_STACK.md 60
g6

p2g1
p2g2
p2g3
p2g4
p2g5
p2g6
p2g7

exit $fail
