# Development Report: Seed Script and BFF Payload Capture (Wave 3.5 Plan 02)

**Branch:** `chore/wave35-seed-and-capture`  
**Date:** 2026-08-10  
**Author:** AI Pair Programmer  

---

## 1. Summary of Changes

Implemented Plan 02 of Wave 3.5 (BFF Reconciliation and Redesign):
1. **Demo User Seed Script (`scripts/seed-demo-user.sh`)**:
   - Created idempotent shell script to register/login `demo@financial.app` / `Demo!2026pass`.
   - Seeded checking account (`0170099200000000000017`), savings account (`0170099200000000000024`), credit card (`4509953566233704`), custom categories (`Supermercado`, `Transporte`, `Sueldo`), 12 transactions across two months, budget over threshold (80% alert threshold on `250000` cap), loan with installments (`Préstamo personal`), and CSV statement import run.
2. **BFF Payload Capture Script (`scripts/capture-bff-payloads.sh`)**:
   - Created script to record real responses from all 9 BFF composition endpoints into `front/financial-app/lib/api/bff/__fixtures__/*.json`.
3. **Backend Service Repairs**:
   - Fixed `@Autowired` constructor injections across 12 WebFlux use-case classes in `ms-gateway`.
   - Updated `JwtAuthFilter` header mutation to pass `X-User-Id` to Spring WebFlux controllers when authenticated via JWT cookies.
   - Fixed Hibernate 6 schema validation errors (`bpchar` column types) in `ms-finances`, `ms-banks`, and `ms-upload`.
   - Updated `OutboxRecordEntity` in `commons-messaging` with `@JdbcTypeCode(SqlTypes.JSON)` and `@Column(columnDefinition = "jsonb")`.
   - Added `@AttributeOverride` in `ms-upload`'s `OutboxEventJpaEntity` for `data_json` `TEXT` column type.
4. **Documentation**:
   - Updated `.ai/references/SCRIPTS.md` with usage instructions for both scripts.
   - Updated `front/financial-app/.ai/references/API_CLIENT.md` documenting the captured BFF JSON fixtures and enforcing the fixture rule for page tests.

---

## 2. Verification Evidence

### Seed Script Idempotency
- Re-ran `./scripts/seed-demo-user.sh` multiple times against the live stack.
- All operations returned 200/201 or skipped cleanly (409 conflicts handled gracefully). Exit code: `0`.

### BFF Endpoint Status Table

| Page / Endpoint | Section | Status | Data Present |
|---|---|---|---|
| `/api/v1/bff/overview` | `kpis`, `netWorth`, `breakdown`, `flow`, `committed`, `upcomingPayments`, `spendByCategory`, `latestMovements` | OK | Yes |
| `/api/v1/bff/banks` | `kpis`, `accounts`, `cards`, `loans`, `importHealth`, `cashDistribution`, `paymentCalendar` | OK | Yes |
| `/api/v1/bff/transactions` | `summary`, `page`, `filterOptions`, `uncategorised` | OK | Yes |
| `/api/v1/bff/categories` | `kpis`, `budgets`, `selectedTrend`, `rules` | OK | Yes |
| `/api/v1/bff/investments` | `marketStrip`, `kpis`, `evolution`, `positions`, `composition`, `recentOperations`, `alerts` | OK | Yes |
| `/api/v1/bff/imports` | `activeRun`, `history`, `reconciliation` | OK | Yes |
| `/api/v1/bff/settings` | `profile`, `preferences`, `fees`, `notificationPrefs`, `sessions` | OK | Yes |

### Fixtures Captured
1. `overview.json`
2. `banks.json`
3. `transactions.json`
4. `transaction-detail.json`
5. `categories.json`
6. `investments.json`
7. `imports.json`
8. `settings.json`
9. `search.json`

### Reproducibility Verification
- Executed `diff -r /tmp/fixtures-run1 front/financial-app/lib/api/bff/__fixtures__ | grep -v observedAt`.
- Output: Empty (byte-identical apart from timestamps).

---

## 3. Self-Correction & Technical Lessons

- **CBU Check-Digit Validation**: `ms-banks` requires valid BCRA modulo-10 check digits (`0170099200000000000017` and `0170099200000000000024`).
- **Postgres `jsonb` & `bpchar` Column Types**: Hibernate 6 schema validation requires `@JdbcTypeCode(SqlTypes.JSON)` for `JSONB` columns, `@Column(columnDefinition = "bpchar")` for fixed-length `CHAR(N)` columns, and `@AttributeOverride` where a specific service table uses `TEXT`.
