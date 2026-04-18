# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Dev Commands

All orchestration goes through `dev.sh`. Run `./dev.sh help` for full reference.

### Recommended local dev workflow
```bash
# Start infra + all default services in background (users, notifications, finances, investments, gateway)
./dev.sh local-all

# Also start frontend
./dev.sh local-all --front

# Specific services only
./dev.sh local-all service-finances service-investments gateway

# Stop everything
./dev.sh stop-all

# Tail logs
./dev.sh logs-local [service-name]
```

### Single service (foreground, hot-reload)
```bash
./dev.sh local service-finances    # infra + one backend service via Maven
./dev.sh front                     # infra + Next.js dev server
```

### Docker
```bash
./dev.sh up      # build + start all (microservice ports exposed)
./dev.sh prod    # build + start all (ports hidden, prod mode)
./dev.sh down
./dev.sh build [service-name]
./dev.sh logs [service-name]
```

### Frontend
```bash
cd front/financial-app
npm run dev      # uses Turbopack
npm run build
npm run lint
```

### Backend (Maven, from service dir)
```bash
cd back/ms-finances
mvn spring-boot:run
mvn test
mvn test -Dtest=SomeSpecificTest
mvn package -DskipTests
```

### Service → port mapping
| Service | Port |
|---|---|
| ms-gateway | 8080 |
| ms-users | 8081 |
| ms-finances | 8082 |
| ms-banks | 8083 |
| ms-notifications | 8084 |
| ms-upload | 8085 |
| ms-investments | 8086 |
| frontend | 3000 |

Swagger UI: `http://localhost:{port}/swagger-ui.html`
Aggregated Swagger (via gateway): `http://localhost:8080/swagger-ui.html`

## Architecture

### Overview

Java microservices behind a Spring Cloud Gateway, Next.js 15 frontend, single PostgreSQL instance with per-service schemas, Kafka for async events, MinIO for file storage.

```
Browser → :3000 (Next.js)
         → :8080 (Gateway) → :8081 ms-users
                           → :8082 ms-finances
                           → :8083 ms-banks
                           → :8084 ms-notifications (skeleton)
                           → :8085 ms-upload (skeleton)
                           → :8086 ms-investments
```

### Gateway (ms-gateway — Spring Cloud Gateway / WebFlux)

Single entry point for all `/api/v1/...` traffic. Key responsibilities:
- **JwtAuthFilter**: reads `access_token` HttpOnly cookie → validates → injects `X-User-Id` header downstream. Auth endpoints (`/api/v1/auth/**`) are exempt.
- **RateLimitFilter**: per-IP token bucket, configurable via `RATE_LIMIT_RPM`.
- **DashboardController + DashboardAggregator**: aggregates summary data from ms-finances and ms-investments for the dashboard page in a single call.
- Routes SSE stream path (`/api/v1/notifications/stream`) with `response-timeout: -1`.
- Proxies `/v3/api-docs/{service}` → each service, enabling aggregated Swagger UI.

### Auth flow

Tokens stored in HttpOnly cookies — never accessible to JS. Four cookies:

| Cookie | HttpOnly | Purpose |
|---|---|---|
| `access_token` | Yes | JWT, 24h, path `/api` |
| `refresh_token` | Yes | JWT, 7d, path `/api/v1/auth/refresh` |
| `user_info` | No | `id\|email\|firstName` URL-encoded, read by middleware |
| `XSRF-TOKEN` | No | CSRF token set by Spring Security |

CSRF: Spring sets `XSRF-TOKEN` cookie; frontend reads it and sends as `X-XSRF-TOKEN` header on all non-GET requests. Auth endpoints are exempt.

The Next.js middleware checks for `user_info` cookie to gate all routes. `apiFetch` (`lib/api/client.ts`) handles 401 → token refresh → retry automatically, with a mutex to prevent concurrent refresh races.

### Backend conventions

- **BOM parent**: `back/financial-app-parent/pom.xml` — Spring Boot 3.4.2, Spring Cloud 2024.0.1, Java 21. Never add version numbers in microservice `pom.xml`.
- **Response wrapper**: every endpoint returns `ApiResponse<T>` (success, message, data, errors, timestamp).
- **Exception handling**: `@RestControllerAdvice` `GlobalExceptionHandler` in each service.
- **DB schema isolation**: each service connects to its own PostgreSQL schema. Hibernate `default_schema` set in `application.yml`. JPA `ddl-auto: validate` — schema managed by Flyway migrations only.
- **Kafka**: internal `kafka:9092`, external `localhost:9093` for local dev. Producers in each service publish domain events; `dev.sh` overrides `KAFKA_BOOTSTRAP_SERVERS` automatically when running locally.
- **Config**: all config via env vars; defaults in `application.yml`. `.env.example` is the canonical reference — never commit `.env`.
- **`@Transactional`**: placed in service layer, not controllers.
- **MapStruct** for entity↔DTO mapping; Lombok for boilerplate.

### ms-banks domain model

Entities: `Bank` (name, logoUrl), `Account` (name, type, balance, currency, isActive). Accounts are linked to banks by `bankId`. Transactions (Plan 04) will link to these accounts.

### ms-finances domain model

Entities: `Transaction`, `Category`/`Subcategory`, `Loan`/`LoanInstallment`, `CardExpense`/`CardExpenseInstallment`. Kafka scheduler fires `payment.due`, `loan.reminder`, `installment.reminder` events for upcoming payments.

### ms-investments domain model

Entities: `Holding` (ticker, type, quantity, avgCost, currency), `AssetPrice`, `AssetPriceHistory`. `IolApiClient` fetches live prices (OHLC + volume + daily variation) from IOL `CotizacionDetalle` endpoint. `PriceRefreshScheduler` triggers periodic refresh (weekdays 10–17 ARS). `PortfolioService` computes P&L and allocation breakdown. `PriceHistoryService` saves a snapshot on each refresh for historical charting.

Key endpoints:
- `GET /api/v1/investments/prices/history/{ticker}?from=&to=` — price history for chart (ISO datetime params)
- `POST /api/v1/investments/prices/refresh` — manual trigger for price refresh

Notification thresholds: `Holding` has `notifyGainThresholdPct` and `notifyLossThresholdPct`. When breached, `lastGainNotifiedAt` / `lastLossNotifiedAt` are stamped. Breach status is shown visually in `HoldingDetailDialog` (client-side computation against `plPercent`).

Flyway migrations in `ms-investments`: V1 (init), V2 (threshold fields), V3 (performance indexes), V4 (OHLC columns on `asset_prices` + `asset_price_history` table).

### Frontend conventions

- **API client** (`lib/api/client.ts`): `api.get/post/put/delete`. Reads `NEXT_PUBLIC_GATEWAY_URL` (default `http://localhost:8080`). Always `credentials: 'include'`. Unwraps `ApiResponse<T>` — callers receive `body.data` directly or an `ApiError`.
- **Data fetching**: TanStack Query hooks in `lib/hooks/use*.ts`. Each hook wraps `api.*` calls.
- **State**: Zustand for UI state (sidebar open/close). No global server-state store — React Query handles that.
- **Auth helpers**: `lib/auth.ts` — `getUserFromCookie()` parses `user_info` cookie, `getCsrfToken()` reads `XSRF-TOKEN`.
- **Layouts**: `(auth)/layout.tsx` (centered, no sidebar) vs `(dashboard)/layout.tsx` (sidebar + header).
- **UI components**: shadcn/ui in `components/ui/`. Charts with Recharts.

### investments frontend features

- `components/pages/dashboard/TopMovers.tsx` — gainers/losers widget on main dashboard; sorted by `plPercent`, top 5 each column, hidden when no price data
- `components/pages/investments/HoldingDetailDialog.tsx` — click any ticker in Holdings tab → dialog with Recharts line chart, 1W/1M/3M/ALL range selector, range change %, threshold breach status + last notification timestamps
- `lib/hooks/useInvestments.ts` — `usePriceHistory(ticker, from?, to?)` hook (staleTime 5 min)
- `types/investments.ts` — `PriceHistory` interface; `HoldingWithPrice` includes `lastGainNotifiedAt`/`lastLossNotifiedAt`

### Infrastructure

- `docker-compose.yml` — base config. `docker-compose.override.yml` exposes microservice ports in dev.
- `--profile app` required to start application services in Docker.
- PostgreSQL init script (`infra/postgres/init/01-create-schemas.sql`) runs once on first container start; re-running `docker compose up` won't re-execute it.
- Build context for all Java services is `./back` (Dockerfiles reference the parent pom + service src).


To continue: claude --resume "btw: Why its taking so long? (Branch)"
