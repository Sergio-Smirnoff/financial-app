#!/usr/bin/env bash
# =============================================================================
# deploy.sh — Bootstrap or update a financial-app server (root repo only)
# =============================================================================
# Images are prebuilt by CI and pulled from GHCR — service sources are NOT
# needed on the server. Only this root repo (compose files, infra/, scripts/).
#
# Usage:
#   chmod +x scripts/deploy.sh
#   ./scripts/deploy.sh               # First run: .env wizard + GHCR login
#   ./scripts/deploy.sh --update      # Pull root repo + images, restart services
#
# Image versions: set <SERVICE>_VERSION vars in .env to pin semver tags
# (e.g. FINANCES_VERSION=1.2.0); unset = latest. Rollback = set previous
# version and re-run with --update.
#
# Prerequisites on server:
#   - git installed (this repo cloned)
#   - docker + docker compose v2 installed
# =============================================================================

set -euo pipefail

# Point DEPLOY_DIR to the root of the project (one level up from scripts/)
DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPDATE_MODE=false

if [[ "${1:-}" == "--update" ]]; then
  UPDATE_MODE=true
fi

# Production compose = base + pinned-version overlay
COMPOSE_FILES=(-f docker-compose.yml -f docker-compose.prod.yml)

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
# Update root repo (compose files, infra/, scripts/) — images come from GHCR
# ---------------------------------------------------------------------------
cd "$DEPLOY_DIR"

if $UPDATE_MODE; then
  info "Updating root repo (master branch) ..."
  git -C "$DEPLOY_DIR" checkout master 2>/dev/null || true
  git -C "$DEPLOY_DIR" pull --ff-only origin master 2>&1 | tail -1
fi

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
  sed -i "s|ALLOWED_ORIGINS=.*|ALLOWED_ORIGINS=https://${DOMAIN_NAME},http://localhost|" "$ENV_FILE"
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
if ! grep -q "^INTERNAL_AUTH_TOKEN=" "$ENV_FILE"; then MISSING_VARS=true; fi

if $MISSING_VARS; then
  warn "Some production variables (Domain, S2S Token) are missing from your .env."
  read -p "Would you like to configure them now? (y/n): " UPDATE_ENV
  if [[ $UPDATE_ENV =~ ^[Yy]$ ]]; then
    if ! grep -q "^DOMAIN_NAME=" "$ENV_FILE"; then
        read -p "  Enter Domain Name (e.g. sergio.duckdns.org): " DOMAIN_NAME
        echo "DOMAIN_NAME=${DOMAIN_NAME}" >> "$ENV_FILE"
    fi
    if ! grep -q "^INTERNAL_AUTH_TOKEN=" "$ENV_FILE"; then
        INTERNAL_AUTH_TOKEN=$(openssl rand -hex 32)
        echo "INTERNAL_AUTH_TOKEN=${INTERNAL_AUTH_TOKEN}" >> "$ENV_FILE"
        info "Generated new INTERNAL_AUTH_TOKEN."
    fi
    # Update URLs to match new domain
    DOMAIN_NAME=$(grep "^DOMAIN_NAME=" "$ENV_FILE" | cut -d'=' -f2-)
    sed -i "s|ALLOWED_ORIGINS=.*|ALLOWED_ORIGINS=https://${DOMAIN_NAME},http://localhost|" "$ENV_FILE"
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
# Update mode: pull pinned/latest images and restart the stack
# ---------------------------------------------------------------------------
if $UPDATE_MODE; then
  info "Pulling app images (pinned in docker-compose.prod.yml) ..."
  docker compose "${COMPOSE_FILES[@]}" --profile app pull
  # Routing/TLS live in the homelab-infra edge stack; the app only joins its
  # network. Compose refuses to start if the external network is absent.
  info "Ensuring external 'edge' network exists ..."
  docker network inspect edge >/dev/null 2>&1 || docker network create edge
  info "Restarting stack ..."
  docker compose "${COMPOSE_FILES[@]}" --profile app up -d
  success "Deploy updated. Status:"
  docker compose "${COMPOSE_FILES[@]}" ps
  exit 0
fi

# ---------------------------------------------------------------------------
# Done (first run)
# ---------------------------------------------------------------------------
echo ""
info "Server bootstrapped. Next steps for Production Deployment:"
echo ""
echo "  1. Edge network:  docker network inspect edge >/dev/null 2>&1 || docker network create edge"
echo "                    (routing/TLS run in the homelab-infra edge stack, not here)"
echo "  2. Start infra:   docker compose -f docker-compose.yml up -d postgres kafka minio"
echo "  3. Pull images:   docker compose -f docker-compose.yml -f docker-compose.prod.yml --profile app pull"
echo "  4. Start app:     docker compose -f docker-compose.yml -f docker-compose.prod.yml --profile app up -d"
echo ""
echo "  Subsequent deploys:  ./scripts/deploy.sh --update   (pulls repo + images, restarts)"
echo "  Pin versions:        set <SERVICE>_VERSION in .env (e.g. FINANCES_VERSION=1.2.0)"
echo ""
echo "  Check status:     docker compose -f docker-compose.yml --profile app ps"
echo ""
echo "  (Note: In production, do NOT use docker-compose.override.yml or 'dev.sh up')"
echo ""
