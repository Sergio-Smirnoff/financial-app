# Financial App

Personal financial management application built with a microservices architecture.

## Stack

- **Frontend**: Next.js 15, React 19, TypeScript, Tailwind CSS 4, shadcn/ui
- **Backend**: Java 25, Spring Boot 3.4, Spring Cloud Gateway
- **Infrastructure**: PostgreSQL, Apache Kafka, MinIO, Docker Compose

## Services

| Service       | Internal Port | Description                    |
|---------------|---------------|--------------------------------|
| Frontend      | 3000 (host)   | Next.js application            |
| Gateway       | 8080 (host)   | API Gateway + JWT validation   |
| Users         | 8081          | Authentication & user profile  |
| Finances      | 8082          | Transactions, loans, expenses  |
| Cards         | 8083          | Credit/debit card management   |
| Notifications | 8084          | Alerts, email, SSE             |
| Upload        | 8085          | File upload + PDF parsing      |

## Quick Start

```bash
# 1. Copy and fill in environment variables
cp .env.example .env

# 2. Start infrastructure (PostgreSQL, Kafka, MinIO)
docker compose up

# 3. Start everything (once all services are built)
docker compose --profile app up
```

## Development Stages

| Stage | Component |
|-------|-----------|
| 1     | Base infrastructure (current) |
| 2     | Users service + JWT |
| 3     | API Gateway |
| 4     | Frontend base |
| 5     | Cards service |
| 6     | Finances service |
| 7     | Notifications service + SSE |
| 8     | Upload service + PDF parsers |

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for full architecture details.
