#!/usr/bin/env bash
# =============================================================================
# dev.sh — Financial App development helper
# =============================================================================
# Usage: ./dev.sh <command> [options]
#
# Commands:
#   infra              Start infrastructure only (postgres, kafka, minio)
#   local <service>    Start infra + run service locally with Maven (hot reload)
#   front              Start infra + run frontend locally with npm dev (hot reload)
#   dev <service>      Start infra + build + run a single service in Docker
#   up                 Start ALL services with ports exposed (dev mode)
#   prod               Start ALL services without exposing microservice ports (production mode)
#   down               Stop and remove all containers
#   restart [svc]      Restart all services or a specific one
#   build [svc]        Build app images (all or specific service)
#   logs [svc]         Follow logs (all or specific service)
#   status             Show running containers
#   ps                 Alias for status
#   help               Show this help
# =============================================================================

set -euo pipefail

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ─── Helpers ──────────────────────────────────────────────────────────────────
info()    { echo -e "${CYAN}${BOLD}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}${BOLD}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}${BOLD}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}${BOLD}[ERROR]${RESET} $*" >&2; }
header()  { echo -e "\n${BOLD}${BLUE}═══ $* ═══${RESET}\n"; }

# ─── Project root ─────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ─── Checks ───────────────────────────────────────────────────────────────────
check_docker() {
    if ! command -v docker &>/dev/null; then
        error "Docker is not installed."
        exit 1
    fi
    if ! docker compose version &>/dev/null; then
        error "Docker Compose plugin not found. Install it with: sudo pacman -S docker-compose"
        exit 1
    fi
}

check_env() {
    if [[ ! -f .env ]]; then
        warn ".env not found — copying from .env.example"
        cp .env.example .env
        warn "Edit .env with your values before continuing."
    fi
}

# ─── Infrastructure services ──────────────────────────────────────────────────
INFRA_SERVICES="postgres zookeeper kafka minio"

# ─── App services ─────────────────────────────────────────────────────────────
APP_SERVICES="gateway service-users service-finances service-cards service-notifications service-upload service-investments frontend"

# =============================================================================
# Commands
# =============================================================================

cmd_infra() {
    header "Starting infrastructure"
    check_docker
    check_env
    docker compose up -d $INFRA_SERVICES
    echo ""
    success "Infrastructure running:"
    echo "  postgres  → localhost:5432"
    echo "  kafka     → localhost:9092 (internal)"
    echo "  minio     → localhost:9000 (S3 API)"
    echo "  minio UI  → localhost:9001"
}

cmd_local() {
    local svc="${1:-}"
    if [[ -z "$svc" ]]; then
        error "Usage: ./dev.sh local <service>"
        echo "  Example: ./dev.sh local service-finances"
        echo ""
        echo "  Available: service-users, service-finances, service-cards,"
        echo "             service-notifications, service-upload, service-investments, gateway"
        exit 1
    fi
    local module
    module=$(_service_to_module "$svc")
    if [[ -z "$module" ]]; then
        error "Unknown service: $svc"
        exit 1
    fi

    header "Local dev — $svc (hot reload)"
    check_docker
    check_env

    info "Starting infrastructure..."
    docker compose up -d $INFRA_SERVICES

    info "Waiting for postgres to be ready..."
    _wait_for_postgres

    local port
    port=$(_service_port "$svc")
    echo ""
    success "Infrastructure ready. Starting $svc locally..."
    if [[ -n "$port" ]]; then
        echo "  Swagger UI  → http://localhost:${port}/swagger-ui.html"
    fi
    echo "  DevTools auto-restart is active — save a file and it reloads."
    echo "  Press Ctrl+C to stop."
    echo ""

    # Export .env vars so Maven picks them up as system env variables
    while IFS= read -r line; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] && export "$line"
    done < "$SCRIPT_DIR/.env"

    cd "$SCRIPT_DIR/back/$module"
    mvn spring-boot:run
}

cmd_front() {
    header "Local dev — frontend (hot reload)"
    check_docker
    check_env

    info "Starting infrastructure..."
    docker compose up -d $INFRA_SERVICES

    echo ""
    success "Infrastructure ready. Starting frontend locally..."
    echo "  App          → http://localhost:3000"
    echo "  Next.js HMR is active — save a file and it reloads instantly."
    echo "  Press Ctrl+C to stop."
    echo ""

    cd "$SCRIPT_DIR/front/financial-app"
    npm run dev
}

cmd_dev() {
    local svc="${1:-}"
    if [[ -z "$svc" ]]; then
        error "Usage: ./dev.sh dev <service>"
        echo "  Example: ./dev.sh dev service-finances"
        exit 1
    fi
    header "Dev mode — $svc"
    check_docker
    check_env

    info "Starting infrastructure..."
    docker compose up -d $INFRA_SERVICES

    info "Waiting for postgres to be ready..."
    _wait_for_postgres

    info "Building $svc..."
    docker compose --profile app build "$svc"

    info "Starting $svc..."
    docker compose --profile app up -d "$svc"

    echo ""
    success "$svc is running."
    local port
    port=$(_service_port "$svc")
    if [[ -n "$port" ]]; then
        echo "  Swagger UI  → http://localhost:${port}/swagger-ui.html"
        echo "  API docs    → http://localhost:${port}/v3/api-docs"
    fi
    echo ""
    info "Following logs (Ctrl+C to exit)..."
    docker compose --profile app logs -f "$svc"
}

cmd_up() {
    header "Starting all services (dev mode)"
    check_docker
    check_env

    info "Building app images..."
    docker compose --profile app build

    info "Starting infrastructure..."
    docker compose up -d $INFRA_SERVICES

    info "Waiting for postgres to be ready..."
    _wait_for_postgres

    info "Starting application services..."
    docker compose --profile app up -d

    echo ""
    success "All services running:"
    echo "  Gateway (API)  → http://localhost:8080"
    echo "  Frontend       → http://localhost:3000"
    echo "  MinIO UI       → http://localhost:9001"
    echo ""
    echo "  Swagger UIs (dev only):"
    echo "    Users         → http://localhost:8081/swagger-ui.html"
    echo "    Finances      → http://localhost:8082/swagger-ui.html"
    echo "    Cards         → http://localhost:8083/swagger-ui.html"
    echo "    Notifications → http://localhost:8084/swagger-ui.html"
    echo "    Upload        → http://localhost:8085/swagger-ui.html"
    echo "    Investments   → http://localhost:8086/swagger-ui.html"
    echo ""
    info "Run './dev.sh logs' to follow all logs."
}

cmd_prod() {
    header "Starting all services (production mode)"
    check_docker
    check_env

    info "Building app images..."
    docker compose -f docker-compose.yml --profile app build

    info "Starting infrastructure..."
    docker compose -f docker-compose.yml up -d $INFRA_SERVICES

    info "Waiting for postgres to be ready..."
    _wait_for_postgres

    info "Starting application services..."
    docker compose -f docker-compose.yml --profile app up -d

    echo ""
    success "All services running (microservice ports NOT exposed):"
    echo "  Gateway (API)  → http://localhost:8080"
    echo "  Frontend       → http://localhost:3000"
    echo "  MinIO UI       → http://localhost:9001"
    echo ""
    info "Run './dev.sh logs' to follow all logs."
}

cmd_down() {
    header "Stopping all services"
    check_docker
    docker compose --profile app down
    success "All containers stopped."
}

cmd_restart() {
    local svc="${1:-}"
    check_docker
    check_env
    if [[ -n "$svc" ]]; then
        header "Restarting $svc"
        docker compose --profile app restart "$svc"
        success "$svc restarted."
    else
        header "Restarting all services"
        docker compose --profile app restart
        success "All services restarted."
    fi
}

cmd_build() {
    local svc="${1:-}"
    check_docker
    check_env
    if [[ -n "$svc" ]]; then
        header "Building $svc"
        docker compose --profile app build "$svc"
        success "$svc image built."
    else
        header "Building all app images"
        docker compose --profile app build
        success "All images built."
    fi
}

cmd_logs() {
    local svc="${1:-}"
    check_docker
    if [[ -n "$svc" ]]; then
        docker compose --profile app logs -f "$svc"
    else
        docker compose --profile app logs -f
    fi
}

cmd_status() {
    check_docker
    header "Container status"
    docker compose --profile app ps
}

# ─── Internal: resolve service name to Maven module ──────────────────────────
_service_to_module() {
    case "$1" in
        service-users)         echo "ms-users" ;;
        service-finances)      echo "ms-finances" ;;
        service-cards)         echo "ms-cards" ;;
        service-notifications) echo "ms-notifications" ;;
        service-upload)        echo "ms-upload" ;;
        service-investments)   echo "ms-investments" ;;
        gateway)               echo "ms-gateway" ;;
        *) echo "" ;;
    esac
}

# ─── Internal: resolve port for a given service ───────────────────────────────
_service_port() {
    case "$1" in
        service-users)         echo "8081" ;;
        service-finances)      echo "8082" ;;
        service-cards)         echo "8083" ;;
        service-notifications) echo "8084" ;;
        service-upload)        echo "8085" ;;
        service-investments)   echo "8086" ;;
        gateway)               echo "8080" ;;
        *) echo "" ;;
    esac
}

# ─── Internal: wait for postgres ──────────────────────────────────────────────
_wait_for_postgres() {
    local retries=20
    local i=0
    while ! docker exec postgres pg_isready -q 2>/dev/null; do
        i=$((i + 1))
        if [[ $i -ge $retries ]]; then
            error "Postgres did not become ready in time."
            exit 1
        fi
        echo -n "."
        sleep 2
    done
    echo ""
    success "Postgres is ready."
}

# ─── Help ─────────────────────────────────────────────────────────────────────
cmd_help() {
    echo ""
    echo -e "${BOLD}Financial App — Dev Helper${RESET}"
    echo ""
    echo -e "  ${CYAN}./dev.sh infra${RESET}                      Start infrastructure (postgres, kafka, minio)"
    echo -e "  ${CYAN}./dev.sh local service-finances${RESET}     Infra + run service locally with Maven (hot reload)"
    echo -e "  ${CYAN}./dev.sh front${RESET}                      Infra + run frontend locally with npm (hot reload)"
    echo -e "  ${CYAN}./dev.sh dev service-finances${RESET}       Infra + build + run a single service in Docker"
    echo -e "  ${CYAN}./dev.sh up${RESET}                         Build + start ALL services (dev — ports exposed)"
    echo -e "  ${CYAN}./dev.sh prod${RESET}                       Build + start ALL services (prod — ports hidden)"
    echo -e "  ${CYAN}./dev.sh down${RESET}                       Stop and remove all containers"
    echo -e "  ${CYAN}./dev.sh build${RESET}                      Rebuild all app images"
    echo -e "  ${CYAN}./dev.sh build service-finances${RESET}     Rebuild a specific service"
    echo -e "  ${CYAN}./dev.sh restart${RESET}                    Restart all app services"
    echo -e "  ${CYAN}./dev.sh restart service-finances${RESET}   Restart a specific service"
    echo -e "  ${CYAN}./dev.sh logs${RESET}                       Follow logs for all services"
    echo -e "  ${CYAN}./dev.sh logs service-finances${RESET}      Follow logs for a specific service"
    echo -e "  ${CYAN}./dev.sh status${RESET}                     Show container status"
    echo ""
    echo -e "  ${YELLOW}Service names:${RESET}"
    echo -e "  gateway, service-users, service-finances, service-cards,"
    echo -e "  service-notifications, service-upload, service-investments, frontend"
    echo ""
    echo -e "  ${YELLOW}Dev Swagger UIs (./dev.sh up or ./dev.sh dev <svc>):${RESET}"
    echo -e "  http://localhost:8081/swagger-ui.html  (users)"
    echo -e "  http://localhost:8082/swagger-ui.html  (finances)"
    echo -e "  http://localhost:8083/swagger-ui.html  (cards)"
    echo -e "  http://localhost:8084/swagger-ui.html  (notifications)"
    echo -e "  http://localhost:8085/swagger-ui.html  (upload)"
    echo -e "  http://localhost:8086/swagger-ui.html  (investments)"
    echo ""
}

# =============================================================================
# Entrypoint
# =============================================================================

COMMAND="${1:-help}"
shift || true

case "$COMMAND" in
    infra)              cmd_infra ;;
    local)              cmd_local "${1:-}" ;;
    front)              cmd_front ;;
    dev)                cmd_dev "${1:-}" ;;
    up)                 cmd_up ;;
    prod)               cmd_prod ;;
    down)               cmd_down ;;
    restart)            cmd_restart "${1:-}" ;;
    build)              cmd_build "${1:-}" ;;
    logs)               cmd_logs "${1:-}" ;;
    status|ps)          cmd_status ;;
    help|--help|-h)     cmd_help ;;
    *)
        error "Unknown command: $COMMAND"
        cmd_help
        exit 1
        ;;
esac
