#!/usr/bin/env bash
# Regenerate the AI tool symlinks that point into .ai/.
# Usage: scripts/ai-link.sh [--check]
#   (no args)  create or refresh every link
#   --check    verify only, exit 1 if any link is wrong or missing
# Auto-loading a context file is a convention each tool implements, not a guarantee.
# To support a tool that reads a different filename, add an entry to LINKS below --
# never fork the content. A tool with no auto-load convention needs a manual paste.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MODE="${1:-link}"
fail=0

LINKS=(
  ".ai/AGENTS.md|CLAUDE.md"
  ".ai/AGENTS.md|AGENTS.md"
  ".ai/AGENTS.md|GEMINI.md"
  ".ai/mcps/mcp_config.json|.mcp.json"
  ".ai/skills|.claude/skills"
  ".ai/agents|.claude/agents"
  ".ai/hooks|.claude/hooks"
)

for entry in "${LINKS[@]}"; do
  target="${entry%%|*}"
  link="${entry##*|}"
  linkdir="$(dirname "$link")"

  if [[ ! -e "$target" ]]; then
    printf 'skip  %-20s target %s absent\n' "$link" "$target"
    continue
  fi

  mkdir -p "$linkdir"
  rel="$(realpath --relative-to="$linkdir" "$target")"

  if [[ "$MODE" == "--check" ]]; then
    actual="$(readlink "$link" 2>/dev/null || true)"
    if [[ "$actual" == "$rel" ]]; then
      printf 'ok    %-20s -> %s\n' "$link" "$rel"
    else
      printf 'FAIL  %-20s -> expected %s, got %s\n' "$link" "$rel" "${actual:-<missing>}"
      fail=1
    fi
  else
    ln -sfn "$rel" "$link"
    printf 'link  %-20s -> %s\n' "$link" "$rel"
  fi
done

REPOS=(
  "back/financial-app-parent" "back/ms-banks" "back/ms-finances" "back/ms-gateway"
  "back/ms-investments" "back/ms-notifications" "back/ms-upload" "back/ms-users"
  "front/financial-app"
)

for repo in "${REPOS[@]}"; do
  target="$repo/.ai/AGENTS.md"
  if [[ ! -e "$target" ]]; then
    printf 'skip  %-34s target %s absent\n' "$repo" "$target"
    continue
  fi
  for name in CLAUDE.md AGENTS.md GEMINI.md; do
    link="$repo/$name"
    rel=".ai/AGENTS.md"
    if [[ "$MODE" == "--check" ]]; then
      actual="$(readlink "$link" 2>/dev/null || true)"
      if [[ "$actual" == "$rel" ]]; then
        printf 'ok    %-34s -> %s\n' "$link" "$rel"
      else
        printf 'FAIL  %-34s -> expected %s, got %s\n' "$link" "$rel" "${actual:-<missing>}"
        fail=1
      fi
    else
      ln -sfn "$rel" "$link"
      printf 'link  %-34s -> %s\n' "$link" "$rel"
    fi
  done
done

exit $fail
