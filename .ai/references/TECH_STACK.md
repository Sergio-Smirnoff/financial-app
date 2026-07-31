# Tech Stack

Version pins live in `back/financial-app-parent/pom.xml` and
`front/financial-app/package.json`. Those files win over this one on conflict.

## Backend

| Concern | Choice |
|---|---|
| Language | Java 21 |
| Framework | Spring Boot 3.4.2 (`spring-boot-starter-parent`) |
| Cloud | Spring Cloud 2024.0.1 — gateway is WebFlux, services are servlet |
| Persistence | Spring Data JPA + Hibernate, `ddl-auto: validate`, Flyway migrations |
| Mapping | MapStruct 1.6.3 (+ `lombok-mapstruct-binding` 0.2.0) |
| Auth | jjwt 0.12.6, bcrypt |
| Object storage | MinIO client 8.5.11 |
| API docs | springdoc-openapi 2.7.0 |
| Messaging | Spring Kafka + CloudEvents, outbox pattern |
| Build | Maven; `mvn verify` is the gate (`RULES.md` R16) |

## Frontend

Next.js 15 (App Router) · React 19 · TypeScript 5 · Tailwind 4 · shadcn on Radix.
State and data: TanStack Query 5, Zustand 5. Forms: react-hook-form + Zod 4 via
`@hookform/resolvers`. Charts: Recharts 3. Toasts: sonner. Icons: lucide-react.
Theming: next-themes. Tooling: ESLint 9 with `eslint-config-next`.

## Infrastructure

Postgres 17 · Kafka `confluentinc/cp-kafka:7.7.0` · MinIO · Traefik v3.0 ·
Grafana + Loki + Promtail + Prometheus · DuckDNS. Service and frontend images publish to
GHCR as `ghcr.io/sergio-smirnoff/financial-app-{back-<service>,front-financial-app}`,
pinned per service by a `*_VERSION` env var defaulting to `latest`.

## Build and dependency order

```
financial-app-parent (BOM)
  └── commons-core ──> commons-web, commons-messaging
        └── the 7 services
```

`back/financial-app-parent` must be `mvn install`-ed before any service builds; `dev.sh`
and every service Dockerfile do this automatically. Services inherit managed versions from
the BOM and never declare versions directly.

`commons-web` and `commons-messaging` both depend on `commons-core`. `ms-gateway` consumes
`commons-core` only — it is WebFlux, and `commons-web` is servlet-bound.

**Cross-repo constraint.** A change to any `commons-*` module must reach the parent repo's
`master` before a dependent service's CI can consume it. Service CI resolves the BOM and
commons artifacts from the published parent, not from your working copy, so a service build
that depends on unmerged commons changes will fail in CI while passing locally.
