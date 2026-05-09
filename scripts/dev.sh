#!/usr/bin/env bash
# =============================================================================
# dev.sh — Financial App development helper
# =============================================================================
# Usage: ./scripts/dev.sh <command> [options]
#
# Commands:
#   local-all [svc...] [--front]   Start infra + selected (or default) services in background
#   stop-all                        Kill all local background processes
#   logs-local [svc]                Tail local log file(s) from ./logs/
#   status-local                    Show which local background processes are alive
#   infra                           Start infrastructure only (postgres, kafka, minio)
#   local <service>                 Start infra + run one service locally with Maven
#   front                           Start infra + run frontend locally with npm
#   dev <service>                   Start infra + build + run a single service in Docker
#   up                              Start ALL services with ports exposed (dev mode)
#   prod                            Start ALL services without exposing microservice ports
#   down                            Stop and remove all containers
#   restart [svc]                   Restart all services or a specific one
#   build [svc]                     Build app images (all or specific service)
#   logs [svc]                      Follow Docker logs (all or specific service)
#   status                          Show running containers
#   ps                              Alias for status
#   help                            Show this help
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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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

# ─── Monitoring services ──────────────────────────────────────────────────────
MONITOR_SERVICES="prometheus grafana loki promtail"

# ─── App services ─────────────────────────────────────────────────────────────
APP_SERVICES="gateway service-users service-finances service-banks service-notifications service-upload service-investments frontend"

# ─── Local-all constants ──────────────────────────────────────────────────────
LOGS_DIR="$SCRIPT_DIR/logs"
PIDS_FILE="$SCRIPT_DIR/.dev-pids"
# Non-skeleton services started by default (gateway always last)
DEFAULT_LOCAL_SERVICES="service-users service-notifications service-finances service-investments service-banks service-upload gateway"

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

cmd_monitor() {
    header "Starting monitoring stack"
    check_docker
    check_env
    docker compose -f docker-compose.monitoring.yml up -d
    echo ""
    success "Monitoring stack running:"
    echo "  prometheus → http://localhost:9090"
    echo "  grafana    → http://localhost:3001"
    echo "  loki       → http://localhost:3100"
}

cmd_local() {
    local svc="${1:-}"
    if [[ -z "$svc" ]]; then
        error "Usage: ./scripts/dev.sh local <service>"
        echo "  Example: ./scripts/dev.sh local service-finances"
        echo ""
        echo "  Available: service-users, service-finances, service-banks,"
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

    # Override Docker-internal hostnames with localhost equivalents for local dev
    export KAFKA_BOOTSTRAP_SERVERS="localhost:9093"
    export DB_URL="jdbc:postgresql://localhost:5432/financialapp?currentSchema=$(_service_schema "$svc")"
    export USERS_SERVICE_URL="http://localhost:8081"
    export FINANCES_SERVICE_URL="http://localhost:8082"
    export BANKS_SERVICE_URL="http://localhost:8083"
    export NOTIFICATIONS_SERVICE_URL="http://localhost:8084"
    export UPLOAD_SERVICE_URL="http://localhost:8085"
    export INVESTMENTS_SERVICE_URL="http://localhost:8086"

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
        error "Usage: ./scripts/dev.sh dev <service>"
        echo "  Example: ./scripts/dev.sh dev service-finances"
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
    echo "  Grafana        → http://localhost:3001"
    echo ""
    echo "  Swagger UIs (dev only):"
    echo "    Users         → http://localhost:8081/swagger-ui.html"
    echo "    Finances      → http://localhost:8082/swagger-ui.html"
    echo "    Banks         → http://localhost:8083/swagger-ui.html"
    echo "    Notifications → http://localhost:8084/swagger-ui.html"
    echo "    Upload        → http://localhost:8085/swagger-ui.html"
    echo "    Investments   → http://localhost:8086/swagger-ui.html"
    echo ""
    info "Run './scripts/dev.sh logs' to follow all logs."
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
    echo "  Grafana        → http://localhost:3001"
    echo ""
    info "Run './scripts/dev.sh logs' to follow all logs."
}

cmd_down() {
    header "Stopping all services"
    check_docker
    docker compose --profile app down
    docker compose -f docker-compose.monitoring.yml down
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
    echo ""
    header "Monitoring status"
    docker compose -f docker-compose.monitoring.yml ps
}

# =============================================================================
# Local-all: run all (or selected) services in background, logs to files
# =============================================================================

cmd_local_all() {
    local services=()
    local run_front=false

    for arg in "$@"; do
        case "$arg" in
            --front) run_front=true ;;
            *) services+=("$arg") ;;
        esac
    done

    if [[ ${#services[@]} -eq 0 ]]; then
        # shellcheck disable=SC2206
        services=($DEFAULT_LOCAL_SERVICES)
    fi

    # Validate service names
    for svc in "${services[@]}"; do
        local mod
        mod=$(_service_to_module "$svc")
        if [[ -z "$mod" ]]; then
            error "Unknown service: $svc"
            echo "  Valid: gateway, service-users, service-finances, service-banks,"
            echo "         service-notifications, service-upload, service-investments"
            exit 1
        fi
    done

    header "Starting local dev environment"
    check_docker
    check_env
    mkdir -p "$LOGS_DIR"
    > "$PIDS_FILE"

    # ── Infra ──────────────────────────────────────────────────────────────────
    info "Starting infrastructure..."
    docker compose up -d $INFRA_SERVICES
    _wait_for_postgres

    # ── Separate gateway from the rest ─────────────────────────────────────────
    local gateway_included=false
    local other_services=()
    for svc in "${services[@]}"; do
        if [[ "$svc" == "gateway" ]]; then
            gateway_included=true
        else
            other_services+=("$svc")
        fi
    done

    # ── Start non-gateway services in parallel ─────────────────────────────────
    if [[ ${#other_services[@]} -gt 0 ]]; then
        info "Launching in parallel: ${other_services[*]}"
        for svc in "${other_services[@]}"; do
            _start_bg "$svc"
            echo "  → $svc  (logs/${svc}.log)"
        done

        info "Waiting for services to be healthy..."
        local all_ok=true
        for svc in "${other_services[@]}"; do
            if ! _wait_healthy "$svc"; then
                all_ok=false
            fi
        done
        if [[ "$all_ok" == false ]]; then
            error "One or more services failed to become healthy. Aborting."
            cmd_stop_all
            exit 1
        fi
    fi

    # ── Gateway last ───────────────────────────────────────────────────────────
    if [[ "$gateway_included" == true ]]; then
        info "Starting gateway..."
        _start_bg "gateway"
        echo "  → gateway  (logs/gateway.log)"
        if ! _wait_healthy "gateway"; then
            error "Gateway failed to become healthy."
            cmd_stop_all
            exit 1
        fi
    fi

    # ── Frontend (optional) ────────────────────────────────────────────────────
    if [[ "$run_front" == true ]]; then
        info "Starting frontend..."
        _start_front_bg
        echo "  → frontend  (logs/front.log)"
    fi

    echo ""
    success "All services running. Logs in ./logs/"
    for svc in "${services[@]}"; do
        local port
        port=$(_service_port "$svc")
        echo "  $svc  → http://localhost:${port}  (logs/${svc}.log)"
    done
    if [[ "$run_front" == true ]]; then
        echo "  frontend   → http://localhost:3000  (logs/front.log)"
    fi
    echo ""
    echo "  Stop with:   ./scripts/dev.sh stop-all"
    echo "  Tail logs:   ./scripts/dev.sh logs-local [service]"
    echo "  Check PIDs:  ./scripts/dev.sh status-local"
}

cmd_stop_all() {
    if [[ ! -f "$PIDS_FILE" ]]; then
        warn "No local processes tracked (.dev-pids not found)."
        return
    fi

    header "Stopping all local processes"

    while IFS=: read -r svc pid; do
        [[ -z "$pid" ]] && continue
        if _kill_tree "$pid"; then
            success "Stopped $svc (PID $pid)"
        else
            warn "$svc (PID $pid) was not running"
        fi
    done < "$PIDS_FILE"

    rm -f "$PIDS_FILE"
    success "Done."
}

cmd_logs_local() {
    local svc="${1:-}"
    if [[ -n "$svc" ]]; then
        local logfile="$LOGS_DIR/${svc}.log"
        if [[ ! -f "$logfile" ]]; then
            error "Log file not found: $logfile"
            exit 1
        fi
        tail -f "$logfile"
    else
        local logfiles=()
        # Collect existing log files
        while IFS= read -r -d '' f; do
            logfiles+=("$f")
        done < <(find "$LOGS_DIR" -maxdepth 1 -name '*.log' -print0 2>/dev/null)
        if [[ ${#logfiles[@]} -eq 0 ]]; then
            warn "No log files found in $LOGS_DIR"
            exit 0
        fi
        tail -f "${logfiles[@]}"
    fi
}

cmd_status_local() {
    if [[ ! -f "$PIDS_FILE" ]]; then
        info "No local processes tracked."
        return
    fi

    header "Local process status"
    while IFS=: read -r svc pid; do
        [[ -z "$pid" ]] && continue
        if kill -0 "$pid" 2>/dev/null; then
            local port
            port=$(_service_port "$svc")
            local url=""
            [[ -n "$port" ]] && url="  http://localhost:${port}"
            echo -e "  ${GREEN}[UP]${RESET}   $svc  (PID $pid)${url}"
        else
            echo -e "  ${RED}[DOWN]${RESET} $svc  (PID $pid — not running)"
        fi
    done < "$PIDS_FILE"
}

# ─── Internal: start a backend service in the background ─────────────────────
_start_bg() {
    local svc="$1"
    local module
    module=$(_service_to_module "$svc")
    local schema
    schema=$(_service_schema "$svc")
    local logfile="$LOGS_DIR/${svc}.log"

    > "$logfile"

    (
        # Load .env into this subshell
        while IFS= read -r line; do
            [[ -z "$line" || "$line" == \#* ]] && continue
            [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] && export "$line"
        done < "$SCRIPT_DIR/.env"

        # Override Docker-internal hostnames with localhost for local dev
        export KAFKA_BOOTSTRAP_SERVERS="localhost:9093"
        export DB_URL="jdbc:postgresql://localhost:5432/financialapp?currentSchema=${schema}"
        export USERS_SERVICE_URL="http://localhost:8081"
        export FINANCES_SERVICE_URL="http://localhost:8082"
        export BANKS_SERVICE_URL="http://localhost:8083"
        export NOTIFICATIONS_SERVICE_URL="http://localhost:8084"
        export UPLOAD_SERVICE_URL="http://localhost:8085"
        export INVESTMENTS_SERVICE_URL="http://localhost:8086"

        cd "$SCRIPT_DIR/back/$module"
        exec nohup mvn spring-boot:run
    ) >> "$logfile" 2>&1 &

    local pid=$!
    echo "${svc}:${pid}" >> "$PIDS_FILE"
}

# ─── Internal: start the frontend in the background ──────────────────────────
_start_front_bg() {
    local logfile="$LOGS_DIR/front.log"
    > "$logfile"

    (
        cd "$SCRIPT_DIR/front/financial-app"
        exec nohup npm run dev
    ) >> "$logfile" 2>&1 &

    local pid=$!
    echo "front:${pid}" >> "$PIDS_FILE"
}

# ─── Internal: wait until a service's /actuator/health returns 200 ───────────
_wait_healthy() {
    local svc="$1"
    local port
    port=$(_service_port "$svc")
    if [[ -z "$port" ]]; then
        warn "No port known for $svc — skipping health check."
        return 0
    fi
    local url="http://localhost:${port}/actuator/health"
    local max_wait=120
    local elapsed=0

    echo -n "  $svc "
    while ! curl -sf "$url" &>/dev/null; do
        sleep 2
        elapsed=$((elapsed + 2))
        echo -n "."
        if [[ $elapsed -ge $max_wait ]]; then
            echo ""
            error "$svc did not become healthy in ${max_wait}s — check logs/${svc}.log"
            return 1
        fi
    done
    echo ""
    success "  $svc healthy"
    return 0
}

# ─── Internal: kill a process and all its descendants ────────────────────────
_kill_tree() {
    local pid="$1"
    local children
    children=$(pgrep -P "$pid" 2>/dev/null || true)
    for child in $children; do
        _kill_tree "$child" || true
    done
    if kill -0 "$pid" 2>/dev/null; then
        kill -TERM "$pid" 2>/dev/null || true
        return 0
    fi
    return 1
}

# ─── Internal: resolve service name to Maven module ──────────────────────────
_service_to_module() {
    case "$1" in
        service-users)         echo "ms-users" ;;
        service-finances)      echo "ms-finances" ;;
        service-banks)         echo "ms-banks" ;;
        service-notifications) echo "ms-notifications" ;;
        service-upload)        echo "ms-upload" ;;
        service-investments)   echo "ms-investments" ;;
        gateway)               echo "ms-gateway" ;;
        *) echo "" ;;
    esac
}

# ─── Internal: resolve schema for a given service ────────────────────────────
_service_schema() {
    case "$1" in
        service-users)         echo "users" ;;
        service-finances)      echo "finances" ;;
        service-banks)         echo "banks" ;;
        service-notifications) echo "notifications" ;;
        service-upload)        echo "upload" ;;
        service-investments)   echo "investments" ;;
        gateway)               echo "public" ;;
        *) echo "public" ;;
    esac
}

# ─── Internal: resolve port for a given service ───────────────────────────────
_service_port() {
    case "$1" in
        service-users)         echo "8081" ;;
        service-finances)      echo "8082" ;;
        service-banks)         echo "8083" ;;
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
    echo -e "  ${BOLD}── Local (all in background) ──────────────────────────────────────────${RESET}"
    echo -e "  ${CYAN}./scripts/dev.sh local-all${RESET}                            Infra + default services in background"
    echo -e "  ${CYAN}./scripts/dev.sh local-all service-users gateway${RESET}      Infra + selected services in background"
    echo -e "  ${CYAN}./scripts/dev.sh local-all --front${RESET}                    Add frontend to the mix"
    echo -e "  ${CYAN}./scripts/dev.sh stop-all${RESET}                             Kill all local background processes"
    echo -e "  ${CYAN}./scripts/dev.sh logs-local${RESET}                           Tail all local log files"
    echo -e "  ${CYAN}./scripts/dev.sh logs-local service-finances${RESET}          Tail a specific log file"
    echo -e "  ${CYAN}./scripts/dev.sh status-local${RESET}                         Show which local processes are alive"
    echo ""
    echo -e "  ${BOLD}── Local (single service, foreground) ────────────────────────────────${RESET}"
    echo -e "  ${CYAN}./scripts/dev.sh local service-finances${RESET}               Infra + run one service with Maven"
    echo -e "  ${CYAN}./scripts/dev.sh front${RESET}                                Infra + run frontend with npm"
    echo ""
    echo -e "  ${BOLD}── Docker ────────────────────────────────────────────────────────────${RESET}"
    echo -e "  ${CYAN}./scripts/dev.sh infra${RESET}                                Start infrastructure only"
    echo -e "  ${CYAN}./scripts/dev.sh monitor${RESET}                              Start monitoring stack only"
    echo -e "  ${CYAN}./scripts/dev.sh dev service-finances${RESET}                 Infra + build + run one service in Docker"
    echo -e "  ${CYAN}./scripts/dev.sh up${RESET}                                   Build + start ALL services (ports exposed)"
    echo -e "  ${CYAN}./scripts/dev.sh prod${RESET}                                 Build + start ALL services (ports hidden)"
    echo -e "  ${CYAN}./scripts/dev.sh down${RESET}                                 Stop and remove all containers"
    echo -e "  ${CYAN}./scripts/dev.sh build [svc]${RESET}                          Rebuild all or specific image"
    echo -e "  ${CYAN}./scripts/dev.sh restart [svc]${RESET}                        Restart all or specific container"
    echo -e "  ${CYAN}./scripts/dev.sh logs [svc]${RESET}                           Follow Docker logs"
    echo -e "  ${CYAN}./scripts/dev.sh status${RESET}                               Show container status"
    echo ""
    echo -e "  ${YELLOW}Service names:${RESET}"
    echo -e "  gateway, service-users, service-finances, service-banks,"
    echo -e "  service-notifications, service-upload, service-investments"
    echo ""
    echo -e "  ${YELLOW}Default local-all services:${RESET} $DEFAULT_LOCAL_SERVICES"
    echo ""
    echo -e "  ${YELLOW}Swagger UIs:${RESET}"
    echo -e "  http://localhost:8081/swagger-ui.html  (users)"
    echo -e "  http://localhost:8082/swagger-ui.html  (finances)"
    echo -e "  http://localhost:8083/swagger-ui.html  (banks)"
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
    monitor)            cmd_monitor ;;
    local)              cmd_local "${1:-}" ;;
    local-all)          cmd_local_all "$@" ;;
    stop-all)           cmd_stop_all ;;
    logs-local)         cmd_logs_local "${1:-}" ;;
    status-local)       cmd_status_local ;;
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
