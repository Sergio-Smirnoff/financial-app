# Rules

Always loaded. Every rule has an id; cite the id in reviews, reports and commit
discussions (`violates R14`) rather than restating the rule.

### R1 — Domain-driven design, always
Every backend change follows the four-layer structure and the dependency rule.
Full definition in the `ddd` skill (`.ai/skills/ddd/SKILL.md`), which loads on
relevance when you design, review or refactor a service.

### R2 — SOLID as applied here
Class design follows the five principles as this codebase applies them, not as
textbooks state them. Full definition in the `solid` skill
(`.ai/skills/solid/SKILL.md`).

### R3 — Reify concepts, never pass bare primitives
A domain concept becomes a value object the moment it has a rule attached. A
`String` that must be 22 digits is a `Cbu`, not a `String`.
✗ `transfer(String cbu, BigDecimal amount)` ✓ `transfer(Cbu cbu, Money amount)`

### R4 — One behavior, one implementation
A behavior is implemented once for the whole repo. If the same rule is needed in
a second place, extract it to a shared type — do not copy it, and do not write a
second variant that drifts.

### R5 — Value objects are rich and self-validating
A VO validates in its constructor, exposes behavior rather than getters, and
carries no `VO`/`Value` suffix. No redundant `of()` factory that only delegates to
an existing constructor. Currency is `java.util.Currency`, never a custom enum.

### R6 — No method-per-enum-state
Branch on the enum value directly. Adding a predicate per state means every new
state edits every existing type.
✗ `status.isOpen()`, `status.isClosed()` ✓ `switch (status) { case OPEN -> ... }`

### R7 — Naming conventions

| Kind | Convention | Example |
|---|---|---|
| Controller | `<Noun>Controller` | `TransactionController` |
| Request DTO | `<Verb><Noun>Request` | `RecordTransactionRequest` |
| Response DTO | `<Noun>Response` | `TransactionResponse` |
| Web mapper | `<Noun>WebMapper` | `TransactionWebMapper` |
| Use case impl | `<Verb><Noun>UseCaseImpl` | `RecordTransactionUseCaseImpl` |
| Aggregate / entity | Singular domain noun, no suffix | `Transaction`, `Holding`, `Loan` |
| Value object | Domain word, no `VO`/`Value` suffix | `Money`, `Cbu`, `Ticker` |
| Domain port (outbound) | `<Noun>Gateway` | `AccountOwnershipGateway` |
| Domain repository port | `<Noun>Repository` | `TransactionRepository` |
| Repository implementation | `<Noun>RepositoryImpl` | `TransactionRepositoryImpl` |
| JPA entity | `<Noun>JpaEntity` | `TransactionJpaEntity` |
| Persistence mapper | `<Noun>PersistenceMapper` | `TransactionPersistenceMapper` |
| Domain exception | `<Reason>Exception` | `InvalidCbuException`, `AccountInsufficientFundsException` |
| Global error handler | `GlobalExceptionHandler` (always this exact name) | — |
| Config class | `<Concern>Config` | `MessagingConfig`, `FeignConfig` |
| Kafka event payload | `<Noun><PastTenseVerb>Event` | `TransactionCreatedEvent` |
| Flyway migration | `V<n>__<snake_case_description>.sql` | `V1__init.sql` |
| REST endpoint | `/api/v1/<service-noun>/...`, plural resource nouns | `/api/v1/finances/transactions` |
| DB table / column | `snake_case` | `outbox_event`, `user_id` |
| Git branch | `<type>/<short-name>`, branched from `master` | `feat/ms-banks-ddd` |

No abbreviations in class/method/field names — `TxDto`, `RepoImpl`, `Mgr` are forbidden.

### R8 — English identifiers only
Classes, methods, fields, columns, endpoints and enum constants are English. No
Spanish in code, including in test names and migration descriptions.
✗ `saldoActual` ✓ `currentBalance`

### R9 — Comments only on request
Write a comment only when the user asks for one, or asks why something is done a
certain way. Never above a class/record/interface declaration. Never restate code.
Method-level Javadoc on a public port is acceptable for a non-obvious contract, when asked.
✗ `// increment counter` above `count++`

### R10 — Every HTTP response uses the envelope
All responses, success and error, are `{status, title, code, message, data}` from
`commons-core`. Shape, examples and the controller pattern:
`.ai/references/APP_STRUCTURE.md` § Response envelope.

### R11 — Never run `git push`
The user controls all remote pushes. Stage and commit locally, then stop and
report. This holds in every repo, including the service repos.

### R12 — Never add a `Co-Authored-By` trailer
Commit messages carry no co-author trailer, ever.

### R13 — Commit only when asked, on a branch off `master`
Do not commit until the user explicitly asks; prepare the change and wait. Work on
`<type>/<name>` branched from `master`, where type is `chore`, `feature` or `hotfix`.
Polyrepo: one branch per affected repo, created independently — never one branch across all.

### R14 — Conventional commit, subject ≤ 50 characters
Format `<type>(<scope>): <subject>`, imperative mood, no trailing period. Add a body
only when the why is not obvious from the diff; never to restate what changed.
```
fix(finances): reject transfers to unowned CBUs
```

### R15 — Ask before destructive changes
Explain why, ask, and wait before dropping a DB column or table, removing a field or
endpoint another service consumes, force-pushing, or any hard-to-reverse change.
Per-prompt approval is preferred over standing blanket permission.

### R16 — `mvn verify` is the gate, not `mvn test`
Done means `mvn verify` passes with no local infra: CI runs on a bare runner with no
Postgres, Kafka or MinIO. Use H2, `EmbeddedKafka`, or an in-process fake.
Jacoco thresholds from each service's `pom.xml` are enforced on every PR.

### R17 — Never suppress a test to reach green
No `@Disabled`, skip, tag-exclude or `@SuppressWarnings` to get a build passing —
fix the root cause instead. `-DskipTests` still compiles tests, so stale test code
breaks Docker builds too.

### R18 — Update the reference and the README after implementing
Every implementation updates that service's reference under `.ai/services/` **and**
that repo's `README.md`. One is the system-wide design record, the other is the
quick-start for someone who clones only that repo; both must stay in sync.
