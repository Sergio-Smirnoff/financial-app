#!/usr/bin/env bash
# =============================================================================
# backup.sh — Backup PostgreSQL database and MinIO data
# =============================================================================
# Usage: ./scripts/backup.sh
# Creates timestamped archives in the ./backups directory.
# =============================================================================

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="${SCRIPT_DIR}/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DB_CONTAINER="postgres"
MINIO_VOLUME_DIR="${SCRIPT_DIR}/infra/minio_data" # Depending on docker volumes, might need docker run to tar it

# ─── Helpers ──────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[backup]${NC} $*"; }
error() { echo -e "${RED}[error]${NC} $*" >&2; }

# ─── Pre-flight Checks ────────────────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
  error "Docker is required but not installed."
  exit 1
fi

mkdir -p "$BACKUP_DIR"

if [[ ! -f "$SCRIPT_DIR/.env" ]]; then
  error "Missing .env file. Cannot read database credentials."
  exit 1
fi

# Source env vars
set -a
source "$SCRIPT_DIR/.env"
set +a

# ─── Database Backup ──────────────────────────────────────────────────────────
info "Starting database backup..."
DB_BACKUP_FILE="${BACKUP_DIR}/db_backup_${TIMESTAMP}.sql.gz"

if docker ps | grep -q "$DB_CONTAINER"; then
  docker exec -t "$DB_CONTAINER" pg_dump -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" | gzip > "$DB_BACKUP_FILE"
  info "Database backup saved to: ${DB_BACKUP_FILE}"
else
  error "Postgres container is not running. Skipping DB backup."
fi

# ─── MinIO Backup ─────────────────────────────────────────────────────────────
info "Starting MinIO backup..."
MINIO_BACKUP_FILE="${BACKUP_DIR}/minio_backup_${TIMESTAMP}.tar.gz"

# Use a temporary alpine container to mount the volume and tar it
# Since volume name is `financial-app_minio_data` (assuming default compose project name)
# We will inspect compose to find exact volume name.
VOLUME_NAME=$(docker volume ls -q | grep "minio_data" | head -n 1 || true)

if [[ -n "$VOLUME_NAME" ]]; then
  docker run --rm -v "${VOLUME_NAME}:/data" -v "${BACKUP_DIR}:/backup" alpine \
    tar -czf "/backup/minio_backup_${TIMESTAMP}.tar.gz" -C / data
  info "MinIO backup saved to: ${MINIO_BACKUP_FILE}"
else
  error "MinIO data volume not found. Skipping MinIO backup."
fi

info "Backup process completed successfully."
