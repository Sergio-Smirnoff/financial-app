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
│  upload :8085                                │
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

1. Client → Gateway → Users service: POST `/api/v1/auth/login`
2. Users service returns signed JWT + Refresh Token
3. Client attaches `Authorization: Bearer {token}` to all requests
4. Gateway validates token on every request before forwarding
5. Refresh via POST `/api/v1/auth/refresh`

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
| JWT over OAuth2 | Personal app, single user |
| Spring Cloud Gateway | Full control over aggregation logic in Java |
| Kafka for notifications | Decoupling, resilience |
| SSE over WebSockets | Server→client only |
| MinIO over PostgreSQL blobs | Separation of concerns, S3-migratable |
| Single PostgreSQL with schemas | Simpler than separate DBs, maintains logical isolation |
| JSON over Avro | Simpler for this scale |
| Single `application.yml` | No profiles needed yet |
| Docker Compose over Kubernetes | Sufficient for personal server |
