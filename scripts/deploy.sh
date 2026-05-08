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
success() { echo -e "${GREEN}[success]${NC} $*"; }
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
ENV_FILE="$DEPLOY_DIR/.env"

if [[ -f "$DEPLOY_DIR/.env.production" && ! -f "$ENV_FILE" ]]; then
  info "Found .env.production. Copying to .env..."
  cp "$DEPLOY_DIR/.env.production" "$ENV_FILE"
elif [[ ! -f "$ENV_FILE" ]]; then
  warn ".env not found! Let's configure it now."
  echo ""
  read -p "Enter Domain Name (e.g. sergio.duckdns.org): " DOMAIN_NAME
  read -p "Are you using DuckDNS? (y/n): " IS_DUCK
  if [[ $IS_DUCK =~ ^[Yy]$ ]]; then
    read -p "  Enter DuckDNS Token: " DUCK_TOKEN
    read -p "  Enter DuckDNS Subdomain (just the name, no .duckdns.org): " DUCK_SUB
  fi
  read -p "Enter Email for Let's Encrypt SSL: " ACME_EMAIL
  read -p "Enter new Postgres password: " PG_PASS
  read -p "Enter new Minio admin password: " MINIO_PASS
  
  JWT_SECRET=$(openssl rand -hex 64)
  INTERNAL_AUTH_TOKEN=$(openssl rand -hex 32)

  cp "$DEPLOY_DIR/.env.example" "$ENV_FILE"
  
  # Replace values in newly generated .env
  sed -i "s/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=${PG_PASS}/" "$ENV_FILE"
  sed -i "s/MINIO_ROOT_PASSWORD=.*/MINIO_ROOT_PASSWORD=${MINIO_PASS}/" "$ENV_FILE"
  sed -i "s/JWT_SECRET=.*/JWT_SECRET=${JWT_SECRET}/" "$ENV_FILE"
  sed -i "s/INTERNAL_AUTH_TOKEN=.*/INTERNAL_AUTH_TOKEN=${INTERNAL_AUTH_TOKEN}/" "$ENV_FILE"
  sed -i "s/DOMAIN_NAME=.*/DOMAIN_NAME=${DOMAIN_NAME}/" "$ENV_FILE"
  sed -i "s/ACME_EMAIL=.*/ACME_EMAIL=${ACME_EMAIL}/" "$ENV_FILE"
  if [[ $IS_DUCK =~ ^[Yy]$ ]]; then
    sed -i "s/DUCKDNS_TOKEN=.*/DUCKDNS_TOKEN=${DUCK_TOKEN}/" "$ENV_FILE"
    sed -i "s/DUCKDNS_DOMAIN=.*/DUCKDNS_DOMAIN=${DUCK_SUB}/" "$ENV_FILE"
  fi
  sed -i "s|ALLOWED_ORIGINS=.*|ALLOWED_ORIGINS=https://${DOMAIN_NAME},http://localhost,http://192.168.0.218|" "$ENV_FILE"
  sed -i "s|NEXT_PUBLIC_GATEWAY_URL=.*|NEXT_PUBLIC_GATEWAY_URL=https://${DOMAIN_NAME}/api|" "$ENV_FILE"
  
  success ".env generated successfully."
else
  info ".env found."
fi

# ---------------------------------------------------------------------------
# Authenticate with GHCR
# ---------------------------------------------------------------------------
info "Authenticating with GitHub Container Registry (GHCR)..."

# Extract credentials safely (grep returns 1 if not found, which triggers set -e)
GH_USER_FROM_ENV=$(grep "^GH_USER=" "$ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'" || echo "")
GH_PAT_FROM_ENV=$(grep "^GH_PAT=" "$ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'" || echo "")

# Check for other missing production variables
MISSING_VARS=false
if ! grep -q "^DOMAIN_NAME=" "$ENV_FILE"; then MISSING_VARS=true; fi
if ! grep -q "^ACME_EMAIL=" "$ENV_FILE"; then MISSING_VARS=true; fi
if ! grep -q "^INTERNAL_AUTH_TOKEN=" "$ENV_FILE"; then MISSING_VARS=true; fi

if $MISSING_VARS; then
  warn "Some production variables (Domain, SSL, S2S Token) are missing from your .env."
  read -p "Would you like to configure them now? (y/n): " UPDATE_ENV
  if [[ $UPDATE_ENV =~ ^[Yy]$ ]]; then
    if ! grep -q "^DOMAIN_NAME=" "$ENV_FILE"; then
        read -p "  Enter Domain Name (e.g. sergio.duckdns.org): " DOMAIN_NAME
        echo "DOMAIN_NAME=${DOMAIN_NAME}" >> "$ENV_FILE"
    fi
    if ! grep -q "^ACME_EMAIL=" "$ENV_FILE"; then
        read -p "  Enter Email for Let's Encrypt SSL: " ACME_EMAIL
        echo "ACME_EMAIL=${ACME_EMAIL}" >> "$ENV_FILE"
    fi
    if ! grep -q "^INTERNAL_AUTH_TOKEN=" "$ENV_FILE"; then
        INTERNAL_AUTH_TOKEN=$(openssl rand -hex 32)
        echo "INTERNAL_AUTH_TOKEN=${INTERNAL_AUTH_TOKEN}" >> "$ENV_FILE"
        info "Generated new INTERNAL_AUTH_TOKEN."
    fi
    # Update URLs to match new domain
    DOMAIN_NAME=$(grep "^DOMAIN_NAME=" "$ENV_FILE" | cut -d'=' -f2-)
    sed -i "s|ALLOWED_ORIGINS=.*|ALLOWED_ORIGINS=https://${DOMAIN_NAME},http://localhost,http://192.168.0.218|" "$ENV_FILE"
    sed -i "s|NEXT_PUBLIC_GATEWAY_URL=.*|NEXT_PUBLIC_GATEWAY_URL=https://${DOMAIN_NAME}/api|" "$ENV_FILE"
    success "Environment updated."
  fi
fi

if [[ -n "${GH_USER_FROM_ENV:-}" && -n "${GH_PAT_FROM_ENV:-}" ]]; then
  echo "$GH_PAT_FROM_ENV" | docker login ghcr.io -u "$GH_USER_FROM_ENV" --password-stdin
  success "Logged into GHCR using credentials from .env."
else
  warn "GHCR credentials not found or incomplete in .env."
  echo "GitHub Container Registry Authentication required to pull images:"
  read -p "Enter GitHub Username: " GH_USER_PROMPT
  read -p "Enter GitHub Personal Access Token (PAT): " GH_PAT_PROMPT
  
  echo "$GH_PAT_PROMPT" | docker login ghcr.io -u "$GH_USER_PROMPT" --password-stdin
  success "Logged into GHCR."
  
  # Ask if user wants to save them for next time
  read -p "Do you want to save these credentials in .env for future deployments? (y/n) " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "" >> "$ENV_FILE"
    echo "# GHCR Credentials" >> "$ENV_FILE"
    echo "GH_USER=${GH_USER_PROMPT}" >> "$ENV_FILE"
    echo "GH_PAT=${GH_PAT_PROMPT}" >> "$ENV_FILE"
    success "Credentials saved to .env."
  fi
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
info "All repos ready. Next steps for Production Deployment:"
echo ""
echo "  1. Start infra:   docker compose -f docker-compose.yml up -d postgres zookeeper kafka minio traefik duckdns"
echo "  2. Start monitor: docker compose -f docker-compose.monitoring.yml up -d"
echo "  3. Pull images:   docker compose -f docker-compose.yml --profile app pull"
echo "  4. Start app:     docker compose -f docker-compose.yml --profile app up -d"
echo "  5. Check status:  docker compose ps"
echo ""
echo "  (Note: In production, do NOT use docker-compose.override.yml or 'dev.sh up')"
echo ""
