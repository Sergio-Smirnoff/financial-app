# Architecture

## Overview

```
[Browser]
    ↓ HTTPS
[Frontend :3000]  ←→  SSE for real-time notifications
    ↓ REST
[API Gateway :8080]  ← JWT validation, routing, aggregation
    ↓ Internal Docker network
┌──────────────────────────────────────────────┐
│              Microservices                   │
│  users :8081        finances :8082           │
│  cards :8083        notifications :8084      │
│  upload :8085       investments :8086        │
└──────────────────────────────────────────────┘
    ↓                        ↓
[PostgreSQL :5432]     [Kafka :9092]
[MinIO :9000]          [Zookeeper :2181]
```

## Rules

- Only Gateway (:8080) and Frontend (:3000) expose ports to the host
- All inter-service communication via Docker internal network
- Each microservice owns exactly one PostgreSQL schema
- No microservice calls another directly for notifications — Kafka only
- Gateway validates JWT; internal services trust blindly

## Authentication Flow

Tokens are stored in **HttpOnly cookies** (not localStorage). The browser sends them automatically.

1. Client → Gateway → Users service: `POST /api/v1/auth/login`
2. Users service sets three cookies on the response:
   - `access_token` (HttpOnly, path `/api`, 24h) — JWT used by the Gateway
   - `refresh_token` (HttpOnly, path `/api/v1/auth/refresh`, 7d) — for silent refresh
   - `user_info` (readable by JS, path `/`, 24h) — URL-encoded `id|email|firstName` for UI
3. Gateway reads `access_token` cookie on every request, validates JWT, injects `X-User-Id` header downstream
4. On 401, frontend calls `POST /api/v1/auth/refresh` (browser sends `refresh_token` cookie automatically), retries original request
5. Logout: `POST /api/v1/auth/logout` — clears all three cookies (maxAge=0)

### CSRF Protection

State-changing requests (POST/PUT/DELETE) require a `X-XSRF-TOKEN` header.

- Users service sets a `XSRF-TOKEN` cookie (non-HttpOnly) via Spring Security's `CookieCsrfTokenRepository`
- Frontend reads `XSRF-TOKEN` from `document.cookie` and sends it as `X-XSRF-TOKEN` on every mutation
- Auth endpoints (`/api/v1/auth/**`) are exempt from CSRF (no cookie exists at login time)

### Cookie summary

| Cookie | HttpOnly | Path | MaxAge | Content |
|--------|----------|------|--------|---------|
| `access_token` | Yes | `/api` | 24h | JWT |
| `refresh_token` | Yes | `/api/v1/auth/refresh` | 7d | JWT (refresh claims) |
| `user_info` | No | `/` | 24h | URL-encoded `id\|email\|firstName` |
| `XSRF-TOKEN` | No | `/` | session | CSRF token |

## Kafka Topics

| Topic                   | Published by | Consumed by           |
|-------------------------|--------------|-----------------------|
| `payment.due`           | Finances     | Notifications         |
| `card.expiring`         | Cards        | Notifications         |
| `card.statement.uploaded` | Upload     | Notifications, Cards  |
| `loan.reminder`         | Finances     | Notifications         |
| `installment.reminder`  | Finances     | Notifications         |

All Kafka messages include: `eventType`, `userId`, `timestamp`, plus event payload.

## Database Schemas

| Schema        | Microservice  |
|---------------|---------------|
| users         | Users         |
| finances      | Finances      |
| cards         | Cards         |
| notifications | Notifications |
| upload        | Upload        |
| investments   | Investments   |

## Maven BOM Parent

All microservices inherit from `financial-app-parent` which inherits from `spring-boot-starter-parent`. No microservice declares dependency versions independently.

## API Standards

- All endpoints: `/api/v1/...`
- Response wrapper: `ApiResponse<T>` on all services
- Global exception handler: `@ControllerAdvice` per service
- `@Transactional` in service layer
- Flyway migrations start from `V1__init.sql`
- Swagger at `/swagger-ui.html` per service; Gateway aggregates all

## Key Decisions

| Decision | Reason |
|---|---|
| JWT in HttpOnly cookies | Protects against XSS (JS can't read the token); CSRF mitigated via double-submit pattern |
| JWT over OAuth2 | Personal app, no third-party auth needed |
| Spring Cloud Gateway | Full control over aggregation logic in Java |
| Kafka for notifications | Decoupling, resilience |
| SSE over WebSockets | Server→client only |
| MinIO over PostgreSQL blobs | Separation of concerns, S3-migratable |
| Single PostgreSQL with schemas | Simpler than separate DBs, maintains logical isolation |
| JSON over Avro | Simpler for this scale |
| Single `application.yml` | No profiles needed yet |
| Docker Compose over Kubernetes | Sufficient for personal server |
