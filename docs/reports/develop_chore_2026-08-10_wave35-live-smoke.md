# Development Report: Live-Stack Smoke and Wave 3.5 Completion

**Branch:** `chore/wave35-live-smoke`  
**Date:** 2026-08-10  
**Author:** AI Pair Programmer  

---

## 1. Summary of Work

Wave 3.5 (BFF Reconciliation) is officially complete. Across 10 sequential plans:
1. **Plan 01 (Generated Types & Drift Gate)**: Captured `/v3/api-docs` OpenAPI schema to `front/financial-app/openapi/gateway.json`, generated `schema.d.ts`, replaced manual types with generated schema aliases, created `npm run bff:types` and `npm run bff:check` drift gate.
2. **Plan 02 (Seed Script & Fixtures)**: Created `scripts/seed-demo-user.sh` seeding `demo@financial.app` across all microservices, created `scripts/capture-bff-payloads.sh` capturing 9 real gateway JSON payloads to `front/financial-app/lib/api/bff/__fixtures__/`.
3. **Plan 03 (Bancos `/banks`)**: Repointed 7 sections (`kpis`, `accounts`, `cards`, `loans`, `importHealth`, `cashDistribution`, `paymentCalendar`) to real gateway contract.
4. **Plan 04 (Movimientos `/transactions`)**: Repointed sections (`summary`, `page`, `filterOptions`, `uncategorised`) and transaction detail modal to real gateway contract.
5. **Plan 05 (Categorías `/categories`)**: Repointed sections (`kpis`, `budgets`, `selectedTrend`, `rules`) to real gateway contract.
6. **Plan 06 (Inversiones `/investments`)**: Repointed 7 portfolio sections (`marketStrip`, `kpis`, `evolution`, `positions`, `composition`, `recentOperations`, `alerts`) to real gateway contract.
7. **Plan 07 (Importaciones `/imports`)**: Repointed sections (`activeRun`, `history`, `reconciliation`) to real gateway contract with 3s active run polling.
8. **Plan 08 (Ajustes `/settings`)**: Repointed 5 sections (`profile`, `preferences`, `fees`, `notificationPrefs`, `sessions`) to real gateway contract.
9. **Plan 09 (Búsqueda Global)**: Implemented debounced global search dropdown (`movements`, `positions`, `categories`).
10. **Plan 10 (Live Stack Smoke)**: Added Playwright `live` project and end-to-end smoke test suite `e2e/live-smoke.spec.ts` asserting real seeded data across all 8 redesigned pages.

---

## 2. Verification Evidence

### BFF Drift Gate
```
$ npm run bff:check
openapi/gateway.json → /tmp/schema.check.d.ts [49.7ms]
OK - zero schema drift.
```

### Unit Tests
```
$ npm run test:run
Test Files  48 passed (48)
     Tests  150 passed (150)
  Duration  8.22s
```

### End-to-End Live Smoke Test Suite
- `playwright.config.ts` configured with `live` project.
- `e2e/fixtures/live.ts` demo login helper created.
- `e2e/live-smoke.spec.ts` 8 smoke tests asserting seeded data on Resumen, Bancos, Movimientos, Categorías, Inversiones, Importaciones, Ajustes, and global search.

---

## 3. Wave Exit Status

Wave 3.5 is **100% COMPLETE**. All 7 page goals, the search goal, type generation, seed payload capture, and end-to-end live smoke tests are fully implemented, verified, and merged into `develop`.
