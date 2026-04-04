# Financial App

Personal financial management application built with a microservices architecture.

## Stack

- **Frontend**: Next.js 15, React 19, TypeScript, Tailwind CSS 4, shadcn/ui
- **Backend**: Java 21, Spring Boot 3.4, Spring Cloud Gateway
- **Infrastructure**: PostgreSQL 17, Apache Kafka, MinIO, Docker Compose

## Services

| Service       | Port | Dev Swagger UI                            | Description                   |
|---------------|------|-------------------------------------------|-------------------------------|
| Frontend      | 3000 | —                                         | Next.js application           |
| Gateway       | 8080 | http://localhost:8080/swagger-ui.html     | API Gateway + JWT validation  |
| Users         | 8081 | http://localhost:8081/swagger-ui.html     | Authentication & user profile |
| Finances      | 8082 | http://localhost:8082/swagger-ui.html     | Transactions, loans, expenses |
| Cards         | 8083 | http://localhost:8083/swagger-ui.html     | Credit/debit card management  |
| Notifications | 8084 | http://localhost:8084/swagger-ui.html     | Alerts, email, SSE            |
| Upload        | 8085 | http://localhost:8085/swagger-ui.html     | File upload + PDF parsing     |

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
./dev.sh <command> [service]
```

| Command | Description |
|---|---|
| `./dev.sh infra` | Start infrastructure only (postgres, kafka, minio) |
| `./dev.sh local <service>` | Infra + run service locally with Maven (**hot reload**) |
| `./dev.sh front` | Infra + run frontend locally with npm (**hot reload**) |
| `./dev.sh dev <service>` | Infra + build + run a single service in Docker |
| `./dev.sh up` | Build + start **all** services in Docker |
| `./dev.sh down` | Stop and remove all containers |
| `./dev.sh build <service>` | Rebuild a specific service image |
| `./dev.sh build` | Rebuild all app images |
| `./dev.sh restart <service>` | Restart a specific service |
| `./dev.sh restart` | Restart all app services |
| `./dev.sh logs <service>` | Follow logs for a specific service |
| `./dev.sh logs` | Follow logs for all services |
| `./dev.sh status` | Show running containers |

### Service names

```
gateway  service-users  service-finances  service-cards
service-notifications  service-upload  frontend
```

### Common workflows

**Local development with hot reload (recommended):**

The fastest dev loop. Infrastructure runs in Docker, services run locally with auto-restart on code changes.

```bash
# Terminal 1: backend service (starts infra + runs with auto-restart on save, ~2-5s)
./dev.sh local service-finances

# Terminal 2: frontend (starts infra + runs with instant HMR in the browser)
./dev.sh front
```

Each command starts the infrastructure automatically if it's not already running. No need to run `./dev.sh infra` separately.

Save a `.java` file → Spring Boot DevTools recompiles and restarts (~2-5s).
Save a `.tsx` file → Next.js applies the change instantly in the browser.

**Requirements:** Java 21, Maven 3.9+, Node.js 22+

All `application.yml` files have sensible localhost defaults, so no env vars are needed for local dev. The parent POM is installed automatically by Maven on first run.

> **Note:** Kafka exposes port `9093` to the host for local dev (`localhost:9093`). Docker containers use the internal `kafka:9092`. The defaults in each `application.yml` already point to `localhost:9093`.

**Run a single service in Docker (no local Java needed):**
```bash
./dev.sh dev service-finances
```
Builds the image, starts the service, and follows its logs. Requires rebuild on code changes.

**Rebuild and restart after a code change (Docker mode):**
```bash
./dev.sh build service-finances
./dev.sh restart service-finances
```

**Start all services in Docker:**
```bash
./dev.sh up
```

**Check what's running:**
```bash
./dev.sh status
```

**Tail logs of a specific service:**
```bash
./dev.sh logs service-finances
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
| 2 | Users service + JWT | ⬜ Pending |
| 3 | API Gateway | ⬜ Pending |
| 4 | Frontend base | ⬜ Pending |
| 5 | Cards service | ⬜ Pending |
| 6 | Finances service | ✅ Done |
| 7 | Notifications service + SSE | ⬜ Pending |
| 8 | Upload service + PDF parsers | ⬜ Pending |

---

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for full architecture details.
