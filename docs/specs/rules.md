# Implementation Rules

Cross-cutting rules every microservice in this project MUST follow. Each section is the single source of truth for its concern; if another document contradicts these rules, raise the conflict rather than silently picking one.

---

## 1. DDD Always

Domain-Driven Design is mandatory on every slice, not optional.

| Rule | Description |
| :-- | :-- |
| No bare primitives | Every meaningful value is a Value Object (`Money`, `Cbu`, `Ticker`, …). Strings, `BigDecimal`, and `int` are only acceptable inside the VO itself. |
| No anemic domain model | Behavior belongs on the entity or VO that owns the data. An entity with only getters/setters and no methods is a violation. |
| Rich VOs | VOs enforce their own invariants in the constructor; they validate, compute, and compare — no outside service needed for that. |
| Meaningful names | Class names, method names, and field names are domain words, never technical abbreviations (`TxDto`, `RepoImpl`, `Mgr`). |
| One behavior, one implementation | A given business rule exists in exactly one place in the codebase. Duplicate behavior is a defect; consolidate on discovery. |
| Factories for construction | Complex aggregates are created through static factory methods or dedicated factory classes. Raw `new` in application/web layers is a smell. |
| No method-per-enum-state | Do not add `isOpen()`, `isClosed()`, `isPending()` — work with the enum value directly. |
| No redundant `of()` factories | Do not add `Currency.of(...)` or analogous thin wrappers that simply delegate to an existing constructor or standard factory. |

---

## 2. SOLID & OOP Principles

Mandatory on every class, in every layer, in every service. DDD (§1) governs WHAT the
model expresses; SOLID governs HOW every class is shaped. A change that satisfies §1 but
violates a principle below is still rejected.

| Principle | Rule in this project | Violation example |
| :-- | :-- | :-- |
| **S** — Single Responsibility | A class has exactly one reason to change. Controllers translate HTTP only; use cases orchestrate exactly one business operation; VOs enforce their own invariants; adapters touch exactly one external system. | A controller that maps DTOs, validates business rules, and calls repositories. |
| **O** — Open/Closed | Extend behavior by adding new classes/enum constants, never by editing stable ones. Service exception handlers extend the shared base and add handlers; new error kinds are new `DomainError` constants — the category→HTTP mapper never changes per code. | Adding an `if (type == X)` branch to an existing class every time a new case appears. |
| **L** — Liskov Substitution | Every subtype is usable wherever its base type is expected, with no surprises. Any `DomainException` subclass flows through the same handler; any port implementation honors the port's full contract. | A repository implementation that throws `UnsupportedOperationException` on one inherited method. |
| **I** — Interface Segregation | Ports expose only what their consumer needs (`SupportedCurrencies` has exactly `isSupported` + `all`). Split interfaces per consumer rather than growing one fat one. | A single `AccountPort` with 15 methods where each adapter implements 3 and stubs 12. |
| **D** — Dependency Inversion | High-level policy depends on abstractions, never on concretions. The domain defines ports; infrastructure implements them. Shared code depends on interfaces (`ErrorCode`), never on concrete service enums. Domain has zero framework imports (ArchUnit-enforced where present). | A use case importing a JPA repository or a Feign client directly. |

OOP baseline that accompanies them: behavior lives with the data it operates on
(encapsulation — see anemic-model rule §1); inheritance only for true is-a
relationships, composition otherwise; no `instanceof`/type-switch chains where
polymorphism does the job.

---

## 3. ApiResponse\<T\> Envelope

Every endpoint in every service returns the shared envelope defined ONCE in
`commons-core` (`com.financialapp.commons.core.response.ApiResponse`, built from
`financial-app-parent`). Services MUST NOT define their own envelope class.

### 3.1 Fields

| Field | Type | Notes |
| :-- | :-- | :-- |
| `status` | `int` | HTTP status code; mirrors the response line. |
| `title` | `String` | HTTP reason phrase, always (`"OK"`, `"Created"`, `"Conflict"`). |
| `code` | `String` | Machine-readable error slug from the service's `DomainError` catalog. Errors only — hidden on success (`@JsonInclude(NON_NULL)`). |
| `message` | `String` | Human-readable note. Optional on success, always present on error. |
| `data` | `T` (any) | Payload on success; structured error details (validation field map, constraint info) on error. Omitted when null. |

### 3.2 Success example

```json
{
  "status": 201,
  "title": "Created",
  "message": "Account created",
  "data": { "cbu": "2850590940090418135201" }
}
```

### 3.3 Error examples

```json
{
  "status": 422,
  "title": "Unprocessable Entity",
  "code": "account_insufficient_funds",
  "message": "Balance 100.00 ARS is less than requested 250.00 ARS",
  "data": { "missing": "150.00" }
}
```

```json
{
  "status": 400,
  "title": "Bad Request",
  "code": "validation_error",
  "message": "Request validation failed",
  "data": { "amount": "must be positive", "currency": "is required" }
}
```

### 3.4 Controller usage

- `200` — `ResponseEntity.ok(ApiResponse.ok(data))` or `ApiResponse.ok(message, data)`
- `201` — `ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created("Created", data))`
- Deletes return **200 + envelope** (not 204) — keeps the envelope universal.
- Errors — produced by the shared `ApiExceptionHandler` base (commons-web) or, for
  service-specific framework exceptions, by `ApiResponse.failure(status, code, message, details)`.
- Every endpoint declares its throwable error codes with `@ApiErrorCodes(catalog = DomainError.class,
  value = {...})` — springdoc examples are generated by `ErrorCodeOperationCustomizer`
  (commons-web auto-configuration), so Swagger never drifts from the catalog.

> **No second envelope class, no per-service `ApiResponse`.** Dropped fields from the previous
> standard: `success` (derive from `status`), `timestamp` (unused), `errors` list (replaced by the
> `data` details map).

---

## 4. Exception Handling

### 4.1 GlobalExceptionHandler

Every servlet service has exactly one `@RestControllerAdvice` class named `GlobalExceptionHandler`
in `web/error/` that **extends `ApiExceptionHandler`** (commons-web). The base provides the
handlers for `DomainException`, bean validation (field map in `data`), malformed JSON,
`DataIntegrityViolationException` (with the `constraintMessages()` template-method hook), and the
generic 500 fallback. Subclasses add only service-specific framework handlers (JWT, Feign,
multipart, ...). ms-gateway (WebFlux) consumes commons-core only and renders the same envelope
from its reactive error paths. No controller method has a `try/catch` for the purpose of shaping
error responses.

### 4.2 Exception hierarchy

```
DomainException (abstract)
├── ResourceNotFoundException          (404)
├── ResourceAlreadyExistsException     (409)
├── ResourceConflictException          (409)
├── InfrastructureException            (500) — bridge: infra throws, use case catches
├── <FooService>Exception              (500) — typed; use case throws after mapping InfrastructureException
└── <module>/
    └── <BusinessRuleException>        (422) — e.g. AccountInsufficientFundsException
```

`InfrastructureException` lives in `domain/exception/` and extends `DomainException`, not in the infrastructure layer (canonical: ms-banks. Current divergence: ms-investments places it in `infrastructure/exception/` and extends `RuntimeException` — migration pending, tracked in [IDEAS.md](IDEAS.md)).

### 4.3 DomainError → HTTP status mapping

The `DomainError` enum owns every HTTP status and machine-readable code string. No HTTP status is assigned at a throw site.

| DomainError constant | HTTP status | Code string |
| :-- | :-- | :-- |
| `RESOURCE_NOT_FOUND` | 404 | `resource_not_found` |
| `RESOURCE_ALREADY_EXISTS` | 409 | `resource_already_exists` |
| `RESOURCE_CONFLICT` / `*_HAS_ACTIVE_*` / `*_NOT_DELETABLE` | 409 | _(domain-specific)_ |
| `ACCOUNT_INSUFFICIENT_FUNDS` | 422 | `account_insufficient_funds` |
| `ACCOUNT_CURRENCY_MISMATCH` | 422 | `account_currency_mismatch` |
| `ACCOUNT_INVESTMENT_RESTRICTION` | 422 | `account_investment_restriction` |
| `ACCOUNT_INVALID_TYPE` | 422 | `account_invalid_type` |
| `CARD_EXPIRED` | 422 | `card_expired` |
| `CARD_INSTALLMENT_ALREADY_PAID` | 409 | `card_installment_already_paid` |
| `LOAN_ALREADY_CLOSED` | 409 | `loan_already_closed` |
| `LOAN_ACCOUNT_MISMATCH` | 422 | `loan_account_mismatch` |
| `INVALID_DATE_RANGE` | 400 | `invalid_date_range` |
| `UNSUPPORTED_CURRENCY` | 422 | `unsupported_currency` |
| `*_SERVICE_UNAVAILABLE` | 500 | `<foo>_service_unavailable` |
| `INTERNAL_ERROR` | 500 | `internal_error` |
| `MethodArgumentNotValidException` (framework) | 400 | `validation_error` |
| `DataIntegrityViolationException` (framework) | 409 | `database_conflict` |

### 4.4 Exception selection guide

| Situation | What to throw |
| :-- | :-- |
| Lookup found nothing | `ResourceNotFoundException("EntityType", identifier)` — from persistence adapter; use case does NOT catch |
| Unique constraint prevents creation | `ResourceAlreadyExistsException("EntityType", identifier)` |
| Delete blocked by dependent data | `ResourceConflictException(DomainError.FOO_HAS_ACTIVE_BARS, message, details)` |
| Domain rule violation on entity state | Typed exception from `domain/exception/<module>/` |
| Infrastructure / Feign call failed — in adapter | `throw new InfrastructureException("ms-foo: " + e.getMessage())` |
| Infrastructure / Feign call failed — in use case | Catch `InfrastructureException`, throw `FooServiceException(operation, cause)` |
| `@Valid` fails on request body | No action — handler catches `MethodArgumentNotValidException` automatically |
| DB unique constraint fired | No action — handler catches `DataIntegrityViolationException` automatically |
| Unexpected runtime failure | Let it bubble to `handleGeneric` → `internal_error` |

### 4.5 Catch order

When a use case may receive both `InfrastructureException` and other `DomainException` subtypes, `catch (InfrastructureException e)` MUST come before `catch (DomainException e)`. `InfrastructureException` extends `DomainException` — reversing the order causes it to be silently consumed.

---

## 5. Configuration

| Rule | Detail |
| :-- | :-- |
| Env vars only | All configuration comes from environment variables; no secrets or environment-specific values in code. |
| `.env.example` is canonical | Every env var the application reads MUST be documented in `.env.example` with a safe default or placeholder. |
| Never commit `.env` | `.env` is gitignored. Committing it is a security violation. |
| `@ConfigurationProperties` | Structured config (lists, nested records) is bound via `@ConfigurationProperties`, not `@Value` splitting or env-var parsing in code. |
| No hardcoded fallback lists | If a config key is required (e.g. supported currencies), use `@NotEmpty` so the application fails fast at startup rather than silently using a hardcoded fallback. |

---

## 6. Persistence

| Rule | Detail |
| :-- | :-- |
| Flyway only | Schema changes are managed exclusively through Flyway migrations (`V1__init.sql`, `V2__...`). JPA `ddl-auto` is set to `validate` — Hibernate never creates or alters tables. |
| Per-service schema | Each service connects to its own PostgreSQL schema. The schema name is set via `spring.jpa.properties.hibernate.default_schema`. No service reads or writes another service's schema. |
| MapStruct for mapping | Entity ↔ DTO conversion uses MapStruct. No manual mapping loops in service or controller code. |
| Lombok for boilerplate | `@Getter`, `@Builder`, `@RequiredArgsConstructor`, etc. via Lombok. No hand-written getters/setters. |
| `@Transactional` in service layer | Transaction boundaries are declared on service-layer methods, never on controllers or persistence adapters. |

---

## 7. Code Comments

> **Comments are added ONLY when the user explicitly asks, or explicitly asks WHY something is implemented a certain way.**

| Prohibition | Reason |
| :-- | :-- |
| No class-top comments or Javadoc on class/record/interface declarations | The name and structure should be self-explanatory. Javadoc on a class declaration is clutter. |
| No inline fully-qualified class names | Use imports. `com.financialapp.banks.domain.exception.DomainError` in a method body is a style violation — add the import instead. |
| No explanatory comments for obvious code | `// increment counter` above `count++` is noise. |

Method-level Javadoc on public API surface (ports, use cases) is acceptable when it documents a non-obvious contract, but only when requested.

---

## 8. Supported Currencies

Currency acceptance is a business policy, not a compile-time constant. The pattern below applies to every service that gates writes by currency.

| Concept | Location | Rule |
| :-- | :-- | :-- |
| `CurrenciesProperties` | `infrastructure/config/` | `@Validated` record; `@NotEmpty Set<@Pattern("[A-Z]{3}") String> supported`. Empty list = boot failure. |
| `SupportedCurrencies` port | `domain/gateway/` | Interface with exactly two methods: `isSupported(Currency)` and `all()`. Framework-free. |
| `SupportedCurrenciesImpl` | `infrastructure/config/` | `@Component`; caches `Set<Currency>` at `@PostConstruct` via `Currency.getInstance(...)`. Returns unmodifiable set. |
| `@SupportedCurrency` annotation | `web/dto/request/` | Custom JSR-303 annotation on request DTO fields. Replaces all hardcoded `@Pattern(regexp = "ARS\|USD")`. |
| `SupportedCurrencyValidator` | `web/dto/request/` | Spring-managed bean; delegates to `SupportedCurrencies` port. `null` → valid (combine with `@NotBlank`). |
| `UnsupportedCurrencyException` | `domain/exception/` | Extends `DomainException`; `DomainError.UNSUPPORTED_CURRENCY` (422). Thrown by non-web entry points (Kafka listeners, scheduled jobs). |

### Currency type rules

- Domain code works with `java.util.Currency` — never raw `String` currency codes past the web boundary.
- `Money(BigDecimal, Currency)` accepts any JDK-known ISO code. Whitelist enforcement is at the boundary, not inside `Money`.
- No `Currency.of(...)` wrapper; use `Currency.getInstance(code)` directly.
- No branching on currency code in use cases (`if ("USD".equals(...))`). Use `Currency` equality or `Collectors.groupingBy` if bucketing is needed.

### Config source

```yaml
<service>:
  currencies:
    supported: [ARS, USD]
```

Adding a currency is a YAML edit and restart — no code change required. Removing a currency is soft: existing rows remain readable; new writes are rejected.

---

## Footer

[Master](00-master.md) | [Architecture](architecture.md) | [Workflow](workflow.md)
