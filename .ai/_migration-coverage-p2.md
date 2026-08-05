# P2 migration coverage

Sources: `docs/specs/services/*.md` (8 files) and the nine untracked `CLAUDE.md` files
snapshotted before deletion. `Verified: yes` means the row's content is present at its target,
**or** that it was dropped to a named owner and that owner carries it.

| Source | Section | Target | Verified |
|---|---|---|---|
| `ms-banks.CLAUDE.md` | Before planning | DROPPED → parent `.ai/references/RULES.md` | yes |
| `ms-banks.CLAUDE.md` | Load-bearing rules | DROPPED → parent `.ai/references/RULES.md` | yes |
| `ms-banks.CLAUDE.md` | Repo facts | `back/ms-banks/.ai/AGENTS.md` | yes |
| `ms-finances.CLAUDE.md` | Before planning | DROPPED → parent `.ai/references/RULES.md` | yes |
| `ms-finances.CLAUDE.md` | Load-bearing rules | DROPPED → parent `.ai/references/RULES.md` | yes |
| `ms-finances.CLAUDE.md` | Repo facts | `back/ms-finances/.ai/AGENTS.md` | yes |
| `ms-gateway.CLAUDE.md` | Before planning | DROPPED → parent `.ai/references/RULES.md` | yes |
| `ms-gateway.CLAUDE.md` | Load-bearing rules | DROPPED → parent `.ai/references/RULES.md` | yes |
| `ms-gateway.CLAUDE.md` | Repo facts | `back/ms-gateway/.ai/AGENTS.md` | yes |
| `ms-investments.CLAUDE.md` | Before planning | DROPPED → parent `.ai/references/RULES.md` | yes |
| `ms-investments.CLAUDE.md` | Load-bearing rules | DROPPED → parent `.ai/references/RULES.md` | yes |
| `ms-investments.CLAUDE.md` | Repo facts | `back/ms-investments/.ai/AGENTS.md` | yes |
| `ms-notifications.CLAUDE.md` | Before planning | DROPPED → parent `.ai/references/RULES.md` | yes |
| `ms-notifications.CLAUDE.md` | Rules (load-bearing — inline) | DROPPED → parent `.ai/references/RULES.md` | yes |
| `ms-notifications.CLAUDE.md` | Repo facts | `back/ms-notifications/.ai/AGENTS.md` | yes |
| `ms-upload.CLAUDE.md` | Before planning any change | DROPPED → parent `.ai/references/RULES.md` | yes |
| `ms-upload.CLAUDE.md` | Load-bearing rules | DROPPED → parent `.ai/references/RULES.md` | yes |
| `ms-upload.CLAUDE.md` | Repo facts | `back/ms-upload/.ai/AGENTS.md` | yes |
| `ms-users.CLAUDE.md` | Before planning | DROPPED → parent `.ai/references/RULES.md` | yes |
| `ms-users.CLAUDE.md` | Load-bearing rules | DROPPED → parent `.ai/references/RULES.md` | yes |
| `ms-users.CLAUDE.md` | Repo facts | `back/ms-users/.ai/AGENTS.md` | yes |
| `financial-app-parent.CLAUDE.md` | Before planning | DROPPED → parent `.ai/references/RULES.md` | yes |
| `financial-app-parent.CLAUDE.md` | Repo facts | `back/financial-app-parent/.ai/AGENTS.md` | yes |
| `financial-app-parent.CLAUDE.md` | Load-bearing rules | DROPPED → parent `.ai/references/RULES.md` | yes |
| `financial-app.CLAUDE.md` | Read First | DROPPED → parent `.ai/references/RULES.md` | yes |
| `financial-app.CLAUDE.md` | Non-Negotiable Rules | DROPPED → parent `.ai/references/RULES.md` | yes |
| `financial-app.CLAUDE.md` | Repo Facts | `front/financial-app/.ai/AGENTS.md` | yes |
| `docs/specs/services/ms-banks.md` | Summary | `back/ms-banks/.ai/AGENTS.md` + human page remainder | yes |
| `docs/specs/services/ms-banks.md` | Domain Model | `back/ms-banks/.ai/references/DOMAIN.md` | yes |
| `docs/specs/services/ms-banks.md` | Aggregates and Value Objects | `back/ms-banks/.ai/references/DOMAIN.md` | yes |
| `docs/specs/services/ms-banks.md` | Enumerations & Domain Services | `back/ms-banks/.ai/references/DOMAIN.md` | yes |
| `docs/specs/services/ms-banks.md` | CBU / BankNumber Contract | `back/ms-banks/.ai/AGENTS.md` & `DOMAIN.md` | yes |
| `docs/specs/services/ms-banks.md` | Response Envelope | DROPPED → parent `.ai/references/APP_STRUCTURE.md` | yes |
| `docs/specs/services/ms-banks.md` | Entity-Relationship Diagram | `back/ms-banks/.ai/references/DOMAIN.md` (compact ERD) | yes |
| `docs/specs/services/ms-banks.md` | Key Flow: Account Balance Adjustment | retained in `docs/specs/services/ms-banks.md` | yes |
| `docs/specs/services/ms-banks.md` | Endpoint Table | `back/ms-banks/.ai/references/API.md` | yes |
| `docs/specs/services/ms-banks.md` | Kafka Integration | `back/ms-banks/.ai/references/EVENTS.md` | yes |
| `docs/specs/services/ms-banks.md` | Scheduled Jobs | `back/ms-banks/.ai/references/EVENTS.md` | yes |
| `docs/specs/services/ms-banks.md` | External Service Calls | `back/ms-banks/.ai/references/EVENTS.md` | yes |
| `docs/specs/services/ms-banks.md` | Folder Tree | `back/ms-banks/.ai/AGENTS.md` | yes |
| `docs/specs/services/ms-banks.md` | Flyway Migrations | `back/ms-banks/.ai/references/DOMAIN.md` | yes |
| `docs/specs/services/ms-banks.md` | CI/CD | DROPPED → parent `.ai/references/PIPELINE.md` | yes |
| `docs/specs/services/ms-finances.md` | Summary / Architecture overview | `back/ms-finances/.ai/AGENTS.md` + human page remainder | yes |
| `docs/specs/services/ms-finances.md` | Account-to-account transaction model | `back/ms-finances/.ai/AGENTS.md` & `DOMAIN.md` | yes |
| `docs/specs/services/ms-finances.md` | Category / Subcategory model | `back/ms-finances/.ai/references/DOMAIN.md` | yes |
| `docs/specs/services/ms-finances.md` | Ranged summary | `back/ms-finances/.ai/references/API.md` | yes |
| `docs/specs/services/ms-finances.md` | Kafka events | `back/ms-finances/.ai/references/EVENTS.md` | yes |
| `docs/specs/services/ms-finances.md` | Entity-relationship diagram | `back/ms-finances/.ai/references/DOMAIN.md` | yes |
| `docs/specs/services/ms-finances.md` | Endpoint table | `back/ms-finances/.ai/references/API.md` | yes |
| `docs/specs/services/ms-finances.md` | Folder tree | `back/ms-finances/.ai/AGENTS.md` | yes |
| `docs/specs/services/ms-finances.md` | Key design rules | DROPPED → parent `.ai/references/RULES.md` | yes |
| `docs/specs/services/ms-finances.md` | CI/CD | DROPPED → parent `.ai/references/PIPELINE.md` | yes |
| `docs/specs/services/ms-gateway.md` | Summary | `back/ms-gateway/.ai/AGENTS.md` + human page remainder | yes |
| `docs/specs/services/ms-gateway.md` | Responsibilities | `back/ms-gateway/.ai/AGENTS.md` & `DOMAIN.md` | yes |
| `docs/specs/services/ms-gateway.md` | Filter Execution Order | `back/ms-gateway/.ai/references/DOMAIN.md` | yes |
| `docs/specs/services/ms-gateway.md` | Authenticated Request — Sequence Diagram | retained in `docs/specs/services/ms-gateway.md` | yes |
| `docs/specs/services/ms-gateway.md` | Currency Domain & 3-Case Conversion Model | `back/ms-gateway/.ai/references/DOMAIN.md` | yes |
| `docs/specs/services/ms-gateway.md` | Endpoint / Route Table | `back/ms-gateway/.ai/references/API.md` | yes |
| `docs/specs/services/ms-gateway.md` | Resilience & Timeout Policy | `back/ms-gateway/.ai/references/DOMAIN.md` | yes |
| `docs/specs/services/ms-gateway.md` | Environment Variables | `back/ms-gateway/.ai/AGENTS.md` & `EXTERNAL.md` | yes |
| `docs/specs/services/ms-investments.md` | Summary | `back/ms-investments/.ai/AGENTS.md` + human page remainder | yes |
| `docs/specs/services/ms-investments.md` | Domain Model | `back/ms-investments/.ai/references/DOMAIN.md` | yes |
| `docs/specs/services/ms-investments.md` | ER Diagram | `back/ms-investments/.ai/references/DOMAIN.md` | yes |
| `docs/specs/services/ms-investments.md` | Price Feed — IOL Integration | `back/ms-investments/.ai/AGENTS.md` & `EVENTS.md` | yes |
| `docs/specs/services/ms-investments.md` | Scheduled Price Refresh — Sequence Diagram | retained in `docs/specs/services/ms-investments.md` | yes |
| `docs/specs/services/ms-investments.md` | Additional Schedulers | `back/ms-investments/.ai/references/EVENTS.md` | yes |
| `docs/specs/services/ms-investments.md` | Portfolio Service | `back/ms-investments/.ai/references/DOMAIN.md` | yes |
| `docs/specs/services/ms-investments.md` | Notification Thresholds | `back/ms-investments/.ai/references/EVENTS.md` | yes |
| `docs/specs/services/ms-investments.md` | Bank-Contract Integration (Buy / Sell Cash Flow) | `back/ms-investments/.ai/AGENTS.md` + human page remainder | yes |
| `docs/specs/services/ms-investments.md` | Flyway Migrations | `back/ms-investments/.ai/references/DOMAIN.md` | yes |
| `docs/specs/services/ms-investments.md` | API Endpoints | `back/ms-investments/.ai/references/API.md` | yes |
| `docs/specs/services/ms-investments.md` | Source Tree | `back/ms-investments/.ai/AGENTS.md` | yes |
| `docs/specs/services/ms-investments.md` | Key Configuration (env vars) | `back/ms-investments/.ai/AGENTS.md` & `EXTERNAL.md` | yes |
| `docs/specs/services/ms-investments.md` | CI/CD | DROPPED → parent `.ai/references/PIPELINE.md` | yes |
| `docs/specs/services/ms-notifications.md` | Summary | `back/ms-notifications/.ai/AGENTS.md` + human page remainder | yes |
| `docs/specs/services/ms-notifications.md` | Folder Tree | `back/ms-notifications/.ai/AGENTS.md` | yes |
| `docs/specs/services/ms-notifications.md` | Entities | `back/ms-notifications/.ai/references/DOMAIN.md` | yes |
| `docs/specs/services/ms-notifications.md` | Flyway Migrations | `back/ms-notifications/.ai/references/DOMAIN.md` | yes |
| `docs/specs/services/ms-notifications.md` | Kafka Consumers | `back/ms-notifications/.ai/references/EVENTS.md` | yes |
| `docs/specs/services/ms-notifications.md` | SSE — Real-Time Stream | `back/ms-notifications/.ai/AGENTS.md` & `API.md` | yes |
| `docs/specs/services/ms-notifications.md` | Endpoint Table | `back/ms-notifications/.ai/references/API.md` | yes |
| `docs/specs/services/ms-notifications.md` | Schedulers | `back/ms-notifications/.ai/references/EVENTS.md` | yes |
| `docs/specs/services/ms-notifications.md` | Event → Persist → SSE Flow | retained in `docs/specs/services/ms-notifications.md` | yes |
| `docs/specs/services/ms-notifications.md` | Email Dispatch | `back/ms-notifications/.ai/references/EVENTS.md` | yes |
| `docs/specs/services/ms-notifications.md` | Configuration (env vars) | `back/ms-notifications/.ai/AGENTS.md` & `EXTERNAL.md` | yes |
| `docs/specs/services/ms-notifications.md` | GOTCHA: UserRegisteredEvent Has No timestamp Field | retained in `docs/specs/services/ms-notifications.md` | yes |
| `docs/specs/services/ms-notifications.md` | CI/CD | DROPPED → parent `.ai/references/PIPELINE.md` | yes |
| `docs/specs/services/ms-upload.md` | Summary | `back/ms-upload/.ai/AGENTS.md` + human page remainder | yes |
| `docs/specs/services/ms-upload.md` | Upload → Preview → Confirm Flow | retained in `docs/specs/services/ms-upload.md` | yes |
| `docs/specs/services/ms-upload.md` | Domain Architecture (Hexagonal) | `back/ms-upload/.ai/AGENTS.md` | yes |
| `docs/specs/services/ms-upload.md` | Endpoint Table | `back/ms-upload/.ai/references/API.md` | yes |
| `docs/specs/services/ms-upload.md` | Folder Tree | `back/ms-upload/.ai/AGENTS.md` | yes |
| `docs/specs/services/ms-upload.md` | Retention & Automation | `back/ms-upload/.ai/references/EVENTS.md` | yes |
| `docs/specs/services/ms-upload.md` | Database Schema (upload) | `back/ms-upload/.ai/references/DOMAIN.md` | yes |
| `docs/specs/services/ms-upload.md` | External Service Calls | `back/ms-upload/.ai/references/EVENTS.md` | yes |
| `docs/specs/services/ms-upload.md` | Key Env Vars | `back/ms-upload/.ai/AGENTS.md` & `EXTERNAL.md` | yes |
| `docs/specs/services/ms-users.md` | Summary | `back/ms-users/.ai/AGENTS.md` + human page remainder | yes |
| `docs/specs/services/ms-users.md` | Session Revocation Trade-off | retained in `docs/specs/services/ms-users.md` | yes |
| `docs/specs/services/ms-users.md` | Folder Tree | `back/ms-users/.ai/AGENTS.md` | yes |
| `docs/specs/services/ms-users.md` | Endpoints | `back/ms-users/.ai/references/API.md` | yes |
| `docs/specs/services/ms-users.md` | JWT & Token Claims | `back/ms-users/.ai/AGENTS.md` & `references/API.md` | yes |
| `docs/specs/services/ms-users.md` | Domain Model & Schema | `back/ms-users/.ai/references/DOMAIN.md` | yes |
| `docs/specs/services/ms-users.md` | Refresh Sequence with Session Validation | retained in `docs/specs/services/ms-users.md` | yes |
| `docs/specs/services/ms-users.md` | Flyway Migrations | `back/ms-users/.ai/references/DOMAIN.md` | yes |
| `docs/specs/services/ms-users.md` | CI/CD | DROPPED → parent `.ai/references/PIPELINE.md` | yes |
| `docs/specs/services/frontend.md` | Summary / Stack | `front/financial-app/.ai/AGENTS.md` | yes |
| `docs/specs/services/frontend.md` | Folder Tree | `front/financial-app/.ai/AGENTS.md` | yes |
| `docs/specs/services/frontend.md` | Routing and Layouts | retained in `docs/specs/services/frontend.md` & `front/financial-app/.ai/references/ROUTES.md` | yes |
| `docs/specs/services/frontend.md` | Middleware | `front/financial-app/.ai/references/ROUTES.md` | yes |
| `docs/specs/services/frontend.md` | API Client | `front/financial-app/.ai/references/API_CLIENT.md` | yes |
| `docs/specs/services/frontend.md` | apiFetch 401 → refresh → retry | retained in `docs/specs/services/frontend.md` & `front/financial-app/.ai/references/API_CLIENT.md` | yes |
| `docs/specs/services/frontend.md` | Auth Helpers | `front/financial-app/.ai/references/API_CLIENT.md` | yes |
| `docs/specs/services/frontend.md` | State Management | `front/financial-app/.ai/references/UI_STATE.md` | yes |
| `docs/specs/services/frontend.md` | Component Areas | `front/financial-app/.ai/references/ROUTES.md` | yes |
| `docs/specs/services/frontend.md` | Recent UX Fixes (2026-06-12) | retained in `docs/specs/services/frontend.md` | yes |
| `docs/specs/services/frontend.md` | Notifications (SSE) | `front/financial-app/.ai/references/UI_STATE.md` | yes |
| `docs/specs/services/frontend.md` | Forms | `front/financial-app/.ai/references/UI_STATE.md` | yes |
| `docs/specs/services/frontend.md` | CI/CD | DROPPED → parent `.ai/references/PIPELINE.md` | yes |
