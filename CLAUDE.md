# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Personal financial app built as microservices, each in its own Docker container, orchestrated with Docker Compose. Development is incremental by stages. All code (classes, methods, variables, endpoints, commits) is in **English**.

## Repository Structure

```
financial-app/                          ← this repo (root)
├── docker-compose.yml
├── .env.example
├── front/
│   └── financial-app/                  ← own git repo (Next.js)
└── back/
    ├── financial-app-parent/           ← Maven BOM parent
    ├── ms-gateway/                     ← own git repo (Spring Cloud Gateway :8080)
    ├── ms-users/                       ← own git repo (:8081)
    ├── ms-finances/                    ← own git repo (:8082)
    ├── ms-cards/                       ← own git repo (:8083)
    ├── ms-notifications/               ← own git repo (:8084)
    └── ms-upload/                      ← own git repo (:8085)
```

## Stack

| Layer | Technology |
|---|---|
| Frontend | Next.js App Router + React + TypeScript + Tailwind CSS + shadcn/ui |
| Frontend server | Apache (Docker) |
| Backend | Java 25 LTS + Spring Boot (latest compatible) + Maven |
| Gateway | Spring Cloud Gateway |
| Messaging | Apache Kafka + Zookeeper (JSON format) |
| Database | PostgreSQL (one schema per microservice, Flyway migrations) |
| Object storage | MinIO (S3-compatible, self-hosted) |
| API docs | Springdoc OpenAPI / Swagger per microservice |
| Containers | Docker + Docker Compose |

## Running the Full Stack

```bash
# Start all services
docker compose up

# Start specific service
docker compose up <service-name>

# Rebuild a service after code changes
docker compose up --build <service-name>
```

Only `gateway` (:8080) and `frontend` (:3000) expose ports to the host. All other services communicate via Docker internal network only.

## Maven BOM Parent

All microservices inherit from `financial-app-parent`. **No microservice declares dependency versions independently.**

```xml
<parent>
    <groupId>com.financialapp</groupId>
    <artifactId>financial-app-parent</artifactId>
    <version>1.0.0</version>
</parent>
```

The parent BOM manages: Spring Boot, Spring Cloud Gateway, Spring Security, Spring Kafka, Spring Data JPA, PostgreSQL driver, Flyway, Springdoc OpenAPI, JWT (jjwt), MinIO SDK, Lombok, MapStruct, Java 25, Maven plugins.

### Build a microservice

```bash
cd back/financial-app-{service}
mvn clean package
mvn test                        # run all tests
mvn test -Dtest=ClassName       # run single test class
```

## Java Microservice Internal Structure

```
src/main/java/com/financialapp/{service}/
├── controller/       ← REST endpoints, all under /api/v1/...
├── service/          ← business logic (@Transactional here)
├── repository/       ← JPA interfaces
├── model/
│   ├── entity/       ← JPA entities
│   └── dto/          ← request/response DTOs
├── exception/        ← custom exceptions + @ControllerAdvice global handler
├── config/           ← service configuration
└── kafka/
    ├── producer/
    ├── consumer/
    └── event/        ← Kafka event DTOs
src/main/resources/
├── application.yml   ← single profile (local only), all config via env vars
└── db/migration/     ← Flyway: V1__init.sql, V2__...
```

## Frontend Internal Structure

```
financial-app/
├── app/
│   ├── (auth)/login/
│   ├── dashboard/
│   ├── cards/
│   ├── finances/
│   ├── notifications/
│   └── profile/
├── components/
│   ├── ui/           ← shadcn/ui components
│   ├── layout/
│   └── shared/
├── lib/
│   ├── api/          ← ALL gateway calls go through here (JWT headers, error handling, interceptors)
│   ├── hooks/
│   └── utils/
└── types/
```

### Frontend commands

```bash
cd front/financial-app
npm install
npm run dev         # development server
npm run build       # production build
npm run lint        # ESLint
```

## Architecture Decisions

- **JWT** (not OAuth2) — personal app, single user, OAuth2 is overkill
- **Spring Cloud Gateway** (not Kong/Nginx) — full control over aggregation logic in Java; aggregates multiple microservice responses into one; validates JWT centrally (microservices trust blindly, no re-validation)
- **Kafka** (not direct REST) for notifications — decoupling, resilience, events not lost
- **SSE** (not WebSockets) for browser push — server→client only, simpler
- **MinIO** (not PostgreSQL blobs) — separation of concerns, S3-migratable
- **Single PostgreSQL instance** with one schema per microservice — simpler than separate DBs, maintains logical isolation
- **JSON in Kafka** (not Avro) — simpler for this scale; each message has `eventType`, `userId`, `timestamp`, plus event-specific payload
- **Single `application.yml`** — no dev/prod profiles yet; production config added when needed
- **Docker Compose** (not Kubernetes) — sufficient for personal server

## Kafka Topics

| Topic | Published by | Consumed by |
|---|---|---|
| `payment.due` | Finances | Notifications |
| `card.expiring` | Cards | Notifications |
| `card.statement.uploaded` | Upload | Notifications, Cards |
| `loan.reminder` | Finances | Notifications |
| `installment.reminder` | Finances | Notifications |

## API Standards

- All endpoints: `/api/v1/...`
- Standardized response wrapper: `ApiResponse<T>` on all services
- Global exception handling: `@ControllerAdvice` in each service
- `@Transactional` in service layer
- Structured logging in all services
- Swagger available at `/swagger-ui.html` and `/v3/api-docs` per service; Gateway aggregates all

## Database

- PostgreSQL schemas: `users`, `finances`, `cards`, `notifications`, `upload`
- Each microservice manages only its own schema
- Flyway migrations start from `V1__init.sql`

## Configuration & Secrets

- All configuration via environment variables — never hardcoded
- Only `.env.example` committed to git, never `.env`
- Each repository has its own `.env.example` documenting all required variables
- JWT secret via env var; passwords hashed with BCrypt

## Development Stages

| Stage | Component |
|---|---|
| 1 | Base infrastructure: folder structure, git, docker-compose, PostgreSQL, MinIO, Kafka, Maven BOM parent |
| 2 | Users microservice + JWT + Refresh Token |
| 3 | API Gateway: JWT validation, routing, aggregation, centralized Swagger |
| 4 | Frontend base: login, navigation, API layer, SSE connected |
| 5 | Cards microservice + Kafka producer |
| 6 | Finances microservice + Kafka producer |
| 7 | Notifications microservice + SSE + Kafka consumers + scheduled jobs |
| 8 | Upload microservice + MinIO + PDF statement parsers |
