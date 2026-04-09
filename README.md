# Financial App

Personal financial management application built with a microservices architecture.

## Stack

- **Frontend**: Next.js 15, React 19, TypeScript, Tailwind CSS 4, shadcn/ui
- **Backend**: Java 21, Spring Boot 3.4, Spring Cloud Gateway
- **Infrastructure**: PostgreSQL 17, Apache Kafka, MinIO, Docker Compose

## Services

| Service       | Port | Dev Swagger UI                            | Description                          |
|---------------|------|-------------------------------------------|--------------------------------------|
| Frontend      | 3000 | —                                         | Next.js application                  |
| Gateway       | 8080 | http://localhost:8080/swagger-ui.html     | API Gateway + JWT validation         |
| Users         | 8081 | http://localhost:8081/swagger-ui.html     | Authentication & user profile        |
| Finances      | 8082 | http://localhost:8082/swagger-ui.html     | Transactions, loans, expenses        |
| Cards         | 8083 | http://localhost:8083/swagger-ui.html     | Credit/debit card management         |
| Notifications | 8084 | http://localhost:8084/swagger-ui.html     | Alerts, email, SSE                   |
| Upload        | 8085 | http://localhost:8085/swagger-ui.html     | File upload + PDF parsing            |
| Investments   | 8086 | http://localhost:8086/swagger-ui.html     | Portfolio tracking + IOL price feeds |

In production (`./dev.sh prod`), only Gateway (8080) and Frontend (3000) are exposed. In dev mode, all service ports are accessible for direct Swagger UI access.

---

## Quick Start

### Prerequisites

- [Docker](https://docs.docker.com/engine/install/) with the Compose plugin (`sudo pacman -S docker-compose` on Arch)
- A `.env` file at the project root (see below)

### 1. Environment variables

```bash
cp .env.example .env
# Edit .env — at minimum set POSTGRES_PASSWORD and JWT_SECRET
```

### 2. Run everything

```bash
./dev.sh up
```

That's it. The script builds all images, starts the infrastructure, waits for Postgres to be ready, then starts all microservices and the frontend.

---

## dev.sh — Development helper

All common operations are available through the `dev.sh` script at the project root.

```
./dev.sh <command> [options]
```

### Local — all services in background (recommended)

| Command | Description |
|---|---|
| `./dev.sh local-all` | Infra + default services in background, logs to `./logs/` |
| `./dev.sh local-all service-users gateway` | Same, but only the specified services |
| `./dev.sh local-all --front` | Include the frontend |
| `./dev.sh stop-all` | Kill all local background processes |
| `./dev.sh logs-local` | `tail -f` all log files in `./logs/` |
| `./dev.sh logs-local service-finances` | `tail -f` a specific log file |
| `./dev.sh status-local` | Show which background processes are alive |

Default services (when none are specified): `service-users`, `service-finances`, `service-investments`, `gateway`.
Startup order: all non-gateway services in parallel → health checks → gateway → frontend (if `--front`).
Log files: `./logs/<service>.log` (truncated on each start). PIDs tracked in `.dev-pids`.

### Local — single service, foreground

| Command | Description |
|---|---|
| `./dev.sh local <service>` | Infra + run one service with Maven (hot reload, Ctrl+C to stop) |
| `./dev.sh front` | Infra + run frontend with npm (hot reload, Ctrl+C to stop) |

### Docker

| Command | Description |
|---|---|
| `./dev.sh infra` | Start infrastructure only (postgres, kafka, minio) |
| `./dev.sh dev <service>` | Infra + build + run a single service in Docker |
| `./dev.sh up` | Build + start **all** services in Docker (ports exposed) |
| `./dev.sh prod` | Build + start **all** services in Docker (only 8080/3000 exposed) |
| `./dev.sh down` | Stop and remove all containers |
| `./dev.sh build [service]` | Rebuild all or a specific image |
| `./dev.sh restart [service]` | Restart all or a specific container |
| `./dev.sh logs [service]` | Follow Docker logs (all or specific) |
| `./dev.sh status` | Show running containers |

### Service names

```
gateway  service-users  service-finances  service-cards
service-notifications  service-upload  service-investments
```

### Common workflows

**All services locally, single command (recommended):**

```bash
# Start everything in the background — terminal stays free
./dev.sh local-all --front

# Tail logs of a specific service
./dev.sh logs-local service-finances

# Stop everything
./dev.sh stop-all
```

Startup sequence: infra (Docker) → non-gateway services in parallel → `/actuator/health` checks → gateway → frontend.

**Requirements:** Java 21, Maven 3.9+, Node.js 22+, `curl`

> **Note:** Kafka exposes port `9093` to the host for local dev. Docker containers use the internal `kafka:9092`. `dev.sh` sets `KAFKA_BOOTSTRAP_SERVERS=localhost:9093` automatically.

**Single service with hot reload (foreground):**

```bash
# Backend — Spring Boot DevTools recompiles on save (~2-5s)
./dev.sh local service-finances

# Frontend — Next.js HMR applies changes instantly
./dev.sh front
```

**Run a single service in Docker (no local Java needed):**
```bash
./dev.sh dev service-finances
```

**Rebuild and restart after a code change (Docker mode):**
```bash
./dev.sh build service-finances
./dev.sh restart service-finances
```

**Start all services in Docker:**
```bash
./dev.sh up
```

**Tear everything down:**
```bash
./dev.sh down
```

---

## Development Stages

| Stage | Component | Status |
|---|---|---|
| 1 | Base infrastructure | ✅ Done |
| 2 | Users service + JWT | ✅ Done |
| 3 | API Gateway | ✅ Done |
| 4 | Frontend | ✅ Done |
| 5 | Cards service | ⬜ Pending |
| 6 | Finances service | ✅ Done |
| 7 | Notifications service + SSE | ⬜ Pending |
| 8 | Upload service + PDF parsers | ⬜ Pending |
| — | Investments service | ✅ Done |

---

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for full architecture details.
