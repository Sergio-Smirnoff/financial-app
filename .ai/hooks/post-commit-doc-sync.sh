#!/usr/bin/env bash
# Git post-commit documentation sync reminder hook.
# Checks if recent commits touch service implementation files without corresponding .ai/ or README updates.
set -euo pipefail

MODIFIED_FILES=$(git diff-tree --no-commit-id --name-only -r HEAD 2>/dev/null || true)

if echo "$MODIFIED_FILES" | grep -qE '^back/|^front/'; then
  if ! echo "$MODIFIED_FILES" | grep -qE '\.ai/|README\.md'; then
    echo "--> [R18 REMINDER] Implementation files were modified. Ensure repo .ai/ references and README.md are updated."
  fi
fi
