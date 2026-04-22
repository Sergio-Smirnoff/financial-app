#!/usr/bin/env bash
# =============================================================================
# deploy.sh — Clone or update all financial-app repositories on a fresh server
# =============================================================================
# Usage:
#   chmod +x scripts/deploy.sh
#   ./scripts/deploy.sh               # Clone all repos (first time)
#   ./scripts/deploy.sh --update      # Pull latest on all repos (subsequent deploys)
#
# Prerequisites on server:
#   - git installed
#   - SSH key added to GitHub (run: ssh -T git@github.com  to verify)
#   - docker + docker compose v2 installed
# =============================================================================

set -euo pipefail

# Point DEPLOY_DIR to the root of the project (one level up from scripts/)
DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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
  "back/ms-banks"
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
  "git@github.com:Sergio-Smirnoff/financial-app-back-ms-banks.git"
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
ssh_output=$(ssh -o StrictHostKeyChecking=no -T git@github.com 2>&1 || true)
if ! echo "$ssh_output" | grep -q "successfully authenticated"; then
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
      info "Updating  $rel_path (master branch) ..."
      git -C "$abs_path" checkout master 2>/dev/null || true
      git -C "$abs_path" pull --ff-only origin master 2>&1 | tail -1
    else
      warn "Already exists: $rel_path  (skipping — use --update to pull)"
    fi
  else
    info "Cloning   $rel_path ..."
    mkdir -p "$(dirname "$abs_path")"
    git clone "$repo_url" "$abs_path"
    git -C "$abs_path" checkout master 2>/dev/null || true
  fi
done

# ---------------------------------------------------------------------------
# Verify or Generate .env
# ---------------------------------------------------------------------------
if [[ ! -f "$DEPLOY_DIR/.env" ]]; then
  warn ".env not found! Let's configure it now."
  echo ""
  read -p "Enter server Public IP (e.g. 201.212.176.73): " PUBLIC_IP
  read -p "Enter new Postgres password: " PG_PASS
  read -p "Enter new Minio admin password: " MINIO_PASS
  echo ""
  echo "GitHub Container Registry (GHCR) Authentication:"
  read -p "Enter GitHub Username: " GH_USER
  read -p "Enter GitHub Personal Access Token (PAT): " GH_PAT
  
  JWT_SECRET=$(openssl rand -hex 64)

  cp "$DEPLOY_DIR/.env.example" "$DEPLOY_DIR/.env"
  
  # Replace values in newly generated .env
  sed -i "s/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=${PG_PASS}/" "$DEPLOY_DIR/.env"
  sed -i "s/MINIO_ROOT_PASSWORD=.*/MINIO_ROOT_PASSWORD=${MINIO_PASS}/" "$DEPLOY_DIR/.env"
  sed -i "s/JWT_SECRET=.*/JWT_SECRET=${JWT_SECRET}/" "$DEPLOY_DIR/.env"
  sed -i "s|ALLOWED_ORIGINS=.*|ALLOWED_ORIGINS=http://${PUBLIC_IP},http://localhost,http://192.168.0.218|" "$DEPLOY_DIR/.env"
  sed -i "s|NEXT_PUBLIC_GATEWAY_URL=.*|NEXT_PUBLIC_GATEWAY_URL=http://${PUBLIC_IP}/api|" "$DEPLOY_DIR/.env"
  
  # Save GHCR credentials to .env to make subsequent logins easier
  echo "" >> "$DEPLOY_DIR/.env"
  echo "# GHCR Credentials" >> "$DEPLOY_DIR/.env"
  echo "GH_USER=${GH_USER}" >> "$DEPLOY_DIR/.env"
  echo "GH_PAT=${GH_PAT}" >> "$DEPLOY_DIR/.env"

  success ".env generated successfully."
else
  info ".env found."
fi

# ---------------------------------------------------------------------------
# Authenticate with GHCR
# ---------------------------------------------------------------------------
info "Authenticating with GitHub Container Registry (GHCR)..."
source "$DEPLOY_DIR/.env"
if [[ -n "${GH_USER:-}" && -n "${GH_PAT:-}" ]]; then
  echo "$GH_PAT" | docker login ghcr.io -u "$GH_USER" --password-stdin
  success "Logged into GHCR."
else
  warn "GH_USER or GH_PAT not found in .env. Skipping GHCR login. Pulls may fail."
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
info "All repos ready. Next steps for Production Deployment:"
echo ""
echo "  1. Start infra:   docker compose -f docker-compose.yml up -d postgres zookeeper kafka minio proxy"
echo "  2. Pull images:   docker compose -f docker-compose.yml --profile app pull"
echo "  3. Start app:     docker compose -f docker-compose.yml --profile app up -d"
echo "  4. Check status:  docker compose ps"
echo ""
echo "  (Note: In production, do NOT use docker-compose.override.yml or 'dev.sh up')"
echo ""
