#!/usr/bin/env bash
# =============================================================================
# deploy.sh — Clone or update all financial-app repositories on a fresh server
# =============================================================================
# Usage:
#   chmod +x deploy.sh
#   ./deploy.sh               # Clone all repos (first time)
#   ./deploy.sh --update      # Pull latest on all repos (subsequent deploys)
#
# Prerequisites on server:
#   - git installed
#   - SSH key added to GitHub (run: ssh -T git@github.com  to verify)
#   - docker + docker compose v2 installed
# =============================================================================

set -euo pipefail

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPDATE_MODE=false

if [[ "${1:-}" == "--update" ]]; then
  UPDATE_MODE=true
fi

# ---------------------------------------------------------------------------
# Repository map: relative_path -> github_repo
# ---------------------------------------------------------------------------
REPO_PATHS=(
  "back/financial-app-parent"
  "back/ms-gateway"
  "back/ms-users"
  "back/ms-finances"
  "back/ms-cards"
  "back/ms-notifications"
  "back/ms-upload"
  "back/ms-investments"
  "front/financial-app"
)

REPO_URLS=(
  "git@github.com:Sergio-Smirnoff/financial-app-back-financial-app-parent.git"
  "git@github.com:Sergio-Smirnoff/financial-app-back-ms-gateway.git"
  "git@github.com:Sergio-Smirnoff/financial-app-back-ms-users.git"
  "git@github.com:Sergio-Smirnoff/financial-app-back-ms-finances.git"
  "git@github.com:Sergio-Smirnoff/financial-app-back-ms-cards.git"
  "git@github.com:Sergio-Smirnoff/financial-app-back-ms-notifications.git"
  "git@github.com:Sergio-Smirnoff/financial-app-back-ms-upload.git"
  "git@github.com:Sergio-Smirnoff/financial-app-back-ms-investments.git"
  "git@github.com:Sergio-Smirnoff/financial-app-front-financial-app.git"
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[deploy]${NC} $*"; }
warn()  { echo -e "${YELLOW}[warn]${NC}  $*"; }
error() { echo -e "${RED}[error]${NC} $*" >&2; }

# ---------------------------------------------------------------------------
# Verify GitHub SSH access
# ---------------------------------------------------------------------------
info "Verifying GitHub SSH access..."
if ! ssh -o StrictHostKeyChecking=no -o BatchMode=yes -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
  error "SSH key not authorized for GitHub."
  echo ""
  echo "  On this server, run:"
  echo "    ssh-keygen -t ed25519 -C 'server-deploy'"
  echo "    cat ~/.ssh/id_ed25519.pub"
  echo "  Then add that key at: https://github.com/settings/ssh/new"
  echo ""
  exit 1
fi
info "GitHub SSH OK."

# ---------------------------------------------------------------------------
# Clone or update each service repo
# ---------------------------------------------------------------------------
cd "$DEPLOY_DIR"

for i in "${!REPO_PATHS[@]}"; do
  rel_path="${REPO_PATHS[$i]}"
  repo_url="${REPO_URLS[$i]}"
  abs_path="$DEPLOY_DIR/$rel_path"

  if [[ -d "$abs_path/.git" ]]; then
    if $UPDATE_MODE; then
      info "Updating  $rel_path ..."
      git -C "$abs_path" pull --ff-only origin master 2>&1 | tail -1
    else
      warn "Already exists: $rel_path  (skipping — use --update to pull)"
    fi
  else
    info "Cloning   $rel_path ..."
    mkdir -p "$(dirname "$abs_path")"
    git clone "$repo_url" "$abs_path"
  fi
done

# ---------------------------------------------------------------------------
# Verify .env exists
# ---------------------------------------------------------------------------
if [[ ! -f "$DEPLOY_DIR/.env" ]]; then
  warn ".env not found! Copy your production env file:"
  echo ""
  echo "  From local machine:"
  echo "    scp .env.production <user>@<server-ip>:$DEPLOY_DIR/.env"
  echo ""
else
  info ".env found."
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
info "All repos ready. Next steps:"
echo ""
echo "  1. Ensure .env is configured  (see .env.example)"
echo "  2. Build images:  docker compose -f docker-compose.yml build"
echo "  3. Start infra:   docker compose -f docker-compose.yml up -d postgres zookeeper kafka minio"
echo "  4. Start app:     docker compose -f docker-compose.yml --profile app up -d"
echo "  5. Check status:  docker compose ps"
echo ""
