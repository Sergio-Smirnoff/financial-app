---
name: ddd
description: Use when designing, reviewing or refactoring any backend service in this repo - defines the four-layer structure, the dependency rule, port and adapter naming, and where each kind of class belongs.
---

## 1. The dependency rule

`domain` never imports `web`, `application`, or `infrastructure`. `web` and `infrastructure` both
depend inward on `domain`; `domain` has zero framework imports and depends on nothing else in the
service. `InfrastructureException` is the one bridge type and it lives in `domain/exception/`:
an infrastructure adapter throws it to signal failure without importing a typed domain service
exception, and the use case that called it catches `InfrastructureException` and re-throws a
specific named exception (`FinancesServiceException`, `InvestmentsServiceException`, ...). ArchUnit's
`LayeredArchitectureTest` enforces the rule mechanically where present — a green build is not proof
by itself, the test has to exist for the service in question.

## 2. Layer responsibilities

- **web** — controllers translate HTTP in and out; DTOs and MapStruct web mappers live here; `GlobalExceptionHandler` (extends commons-web `ApiExceptionHandler`) serializes every exception into the envelope. No business logic.
- **application** — use-case implementations orchestrate exactly one business operation each, calling domain services, repositories, and gateways through their ports. No persistence or HTTP detail leaks in.
- **domain** — entities, value objects, domain services, domain events, and the outbound ports (`gateway`, `repository`, `usecase` interfaces). Pure logic, no framework imports, no `new` for complex aggregates outside factories.
- **infrastructure** — JPA entities and repositories, Feign-backed gateway implementations, Kafka producers/listeners, config classes. Implements the ports `domain` defines; never defines new business rules.

## 3. Package convention

Identical across all 7 backend services. Canonical form — do not
compress or reorder this tree, it is the single most-consulted artifact in the repo:

```
com.financialapp.<service>/
├── <Service>Application.java
├── web/
│   ├── controller/        <Noun>Controller.java
│   ├── dto/request/       <Verb><Noun>Request.java
│   ├── dto/response/      <Noun>Response.java
│   ├── mapper/             <Noun>WebMapper.java          (MapStruct)
│   └── error/              GlobalExceptionHandler.java    (extends commons-web ApiExceptionHandler)
├── application/<module>/impl/
│   └── <Verb><Noun>UseCaseImpl.java
├── domain/
│   ├── common/model/       cross-module VOs (Money, UserId, ...)
│   ├── model/<module>/     aggregates, VOs, enums for that module
│   ├── event/              DomainEvent + subtypes
│   ├── service/            domain services (pure logic, no framework)
│   ├── gateway/             <Noun>Gateway.java            (ports — outbound interfaces)
│   ├── repository/          <Noun>Repository.java          (port — persistence interface)
│   ├── usecase/<module>/    use-case interfaces + command records
│   └── exception/           DomainException tree, DomainError enum
└── infrastructure/
    ├── config/              FeignConfig, MessagingConfig, *Impl for domain ports
    ├── persistence/entity/  <Noun>JpaEntity.java
    ├── persistence/mapper/  <Noun>PersistenceMapper.java
    ├── persistence/repository/ <Noun>RepositoryImpl.java   (implements domain/repository port)
    ├── messaging/           Outbox publisher, event mappers, Kafka listeners
    ├── gateway/Impl/         Feign-backed implementations of domain/gateway ports
    └── scheduler/            OutboxRelay, cron jobs
```

## 4. `ms-gateway` exception

`ms-gateway` is WebFlux, not servlet. Since Wave 4 Round A it carries the full four-layer split —
it **does** have an `application` layer (13 BFF use-case impls), so §1's dependency rule and §2's
layer responsibilities apply to it unchanged. Two things stay gateway-specific: no JPA — it is a
routing/BFF layer, not a persistence-owning service — and it consumes `commons-core` only, not
`commons-web`.

## 5. Aggregate rules

Aggregate and value-object invariants that hold in every service:

- Aggregates own their invariants — validation and computation happen on the entity or VO that owns the data, never in a use case or a helper.
- Value objects are immutable and validate themselves in the constructor; no outside service is needed to make them consistent.
- No anemic domain model — an entity with only getters/setters and no behavior is a violation.
- No framework annotations in `domain/` — JPA, Jackson, and Spring annotations belong on infrastructure/web types, never on domain entities or VOs.
