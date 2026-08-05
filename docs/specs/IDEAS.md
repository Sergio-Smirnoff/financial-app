# Ideas

A running backlog of future ideas — features, improvements, refactors, and things to keep in
mind. This is **not** a commitment list; it's a scratchpad to capture thoughts before they're
lost. Promote an idea to a real spec + plan (via the brainstorming → writing-plans flow) when
it's ready to build.

## How to use this file

- Add an idea under the right section with a short title + one or two lines of context.
- Optional tags: `[feature]` `[refactor]` `[infra]` `[ux]` `[tech-debt]` `[research]`.
- When an idea becomes real work, move it to **In progress / promoted** with a link to its
  spec in `docs/specs/` (or `docs/superpowers/specs/`), then delete it from the backlog.

## Backlog

### Features
- Add the thesis to the investments
- Add to workflow the use of Notion insead of this Ideas.md, to manage task / features / histories to be done. With this we can track progress, backlog and status of the project
- grafana dashboards and alerts
- Add csv download for history and holdings
- allow money exchange in banks section

### Bugs
- **Notifications SSE reconnect storm floods the console.** The browser hammers `GET /api/v1/notifications/stream` and logs `net::ERR_NETWORK_CHANGED` dozens of times per minute (sometimes paired with `200 (OK)`). The EventSource has no backoff/jitter and reconnects immediately on every drop, so any network blip (or the gateway closing idle SSE connections) produces an endless retry loop. Fixes: add exponential backoff + jitter on reconnect, cap retries, and stop tearing down/recreating the stream on transient `readyState` changes; server side, keep SSE connections alive (heartbeat/`retry:` field) so the client doesn't churn. `[ux]` `[front]`
- **`DialogContent` missing `Description` / `aria-describedby` (a11y warning).** React logs `Warning: Missing 'Description' or 'aria-describedby={undefined}' for {DialogContent}` on several dialogs. Radix/shadcn `DialogContent` requires either a `<DialogDescription>` or `aria-describedby` for screen-reader support. Audit all dialogs and add a `DialogDescription` (or `aria-describedby={undefined}` opt-out where genuinely none applies). `[ux]` `[a11y]` `[front]`
- **Market Discovery empty when IOL auth fails (silent degradation).** `/investments` Market Discovery showed "You own all trending assets!" and ticker search returned nothing because the `market_quotes` cache was empty — root cause was IOL `POST /token` returning `401` (prod `IOL_PASSWORD` was corrupted: 15 chars vs the correct 14; also the IOL account had been device-blocked). The panel sync swallows the failure (`getPanelQuotes` returns `List.of()` on error) so the UI silently shows the empty-state instead of surfacing "market data unavailable". Resolved operationally 2026-06-13 by fixing the prod password + recreating `service-investments`. Follow-up: distinguish "you own everything" from "upstream IOL unavailable" in the API/UI, and add a health signal/alert when panel sync returns 0 titles repeatedly. `[ux]` `[ops]` `[investments]`
- **Account creation fails when `alias` omitted (alias should be optional).** POST `/api/v1/banks/accounts` without an `alias` returns a misleading `409 database_conflict / unknown_constraint`. Real cause: `banks.accounts.alias` is `NOT NULL` (migration `V7`) with no default, so the insert sends `alias = null` → Postgres `23502` not-null violation. `alias` is meant to be **optional**. Fixes: (1) ms-banks — make `alias` optional: default it when omitted (e.g. to `name` or `cbu`) or make the column nullable, so creation succeeds without an alias; (2) commons `ApiExceptionHandler` — map SQLState `23502` (not-null) to **400** naming the column, not `409 database_conflict / unknown_constraint` (the current catch-all for every `DataIntegrityViolationException` mislabels not-null/check violations as conflicts).
- Fix chart display bug, showing prices that does not exist, graph has no axes and its showing more movements in the curve than the amount of pricies points that the graph has

### Improvements & refactors
- Change all the JWT system and the auth tokens
- refactor some pages of the front end: categories, configuration, uploads
- Look for @Disable in tests

### Infrastructure & tooling
- review network

### Research / open questions
- mail server
- message connection
- uploads migration, best way to reimplemented

### Tech-debt — code/canon divergences (found in 2026-06-04 doc QA)
- ms-finances names its exception advice `DomainExceptionHandler`; canon (rules.md) is
  `GlobalExceptionHandler`. Rename. `[refactor]` `[tech-debt]`
- ms-investments `InfrastructureException` lives in `infrastructure/exception/` and extends
  `RuntimeException`; canon is `domain/exception/` extending `DomainException` (as in ms-banks).
  Migrate so catch-ordering in use cases is correct. `[refactor]` `[tech-debt]`
- Frontend `types/notifications.ts` `NotificationType` union declares only 6 of the backend's
  10 values (missing `CARD_EXPIRING`, `LOW_BALANCE`, `TRANSFER_SENT`, `TRANSFER_RECEIVED`) —
  those notifications fail TS narrowing. `[ux]` `[tech-debt]`
- Frontend declares numeric fields as `number` but ms-investments serialises money as `String`
  over the wire — type mismatch for callers. Align frontend types. `[ux]` `[tech-debt]`
## In progress / promoted

- Consolidate `Cbu` value object into `commons-core` → resolved 2026-08-05 (`com.financialapp.commons.core.domain.model.Cbu`)
- Clean up `ms-upload` dead wiring (`spring-kafka`, `BanksClient`) → resolved 2026-08-05
- Document ms-banks V6 `processed_events` legacy table status → resolved 2026-08-05
- AI Context Baseline Restructure (P1, P2, P3, P4) → completed 2026-08-05
- Host the application on the cloud → researched, spec: [2026-06-05-cloud-hosting-research.md](../superpowers/specs/2026-06-05-cloud-hosting-research.md)
- Java 25 migration → researched, decision: Boot 4.0 + SC 2025.1 + Java 25, spec: [2026-06-05-java-25-spring-boot-4-migration.md](../superpowers/specs/2026-06-05-java-25-spring-boot-4-migration.md)

---

[Master](00-master.md)
