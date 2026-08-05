#!/usr/bin/env bash
# Git pre-commit verification hook for financial-app.
# Executes scripts/ai-verify.sh --check to ensure no gate regressions occur before committing.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

if [[ -f "$ROOT/scripts/ai-verify.sh" ]]; then
  echo "--> Running AI context verification gate..."
  bash "$ROOT/scripts/ai-verify.sh"
else
  echo "--> Warning: scripts/ai-verify.sh missing, skipping gate verification."
fi
