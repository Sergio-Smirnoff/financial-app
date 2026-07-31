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
g2() {
  local hits
  hits=$($GREP -rl \
    -e 'docs/specs/rules' -e 'docs/specs/workflow' -e 'docs/specs/architecture' \
    -e 'docs/specs/deployment' -e 'docs/specs/00-master' . \
    --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=back \
    --exclude-dir=front --exclude-dir=superpowers 2>/dev/null \
    | $GREP -v 'ai-restructure-p1' | $GREP -v 'ai-verify.sh' \
    | $GREP -v '_migration-coverage' || true)
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

g2
g4
g5
check_cap .ai/AGENTS.md               120
check_cap .ai/references/RULES.md     150
check_cap .ai/references/ARCHITECTURE.md 120
check_cap .ai/references/WORKFLOW.md  100
check_cap .ai/references/TECH_STACK.md 60
g6

exit $fail
