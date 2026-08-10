# Development Report — Wave 3 · Plan 10 — Inversiones Page (`/investments`)

**Branch:** `feat/wave3-page-inversiones`  
**Date:** 2026-08-10  
**Repo:** `front/financial-app`  
**Status:** ✅ Complete — merged to `develop`

---

## What was built

- **`useInvestmentsPage` Hook** (`lib/hooks/useInvestmentsPage.ts`): Single query hook consuming `GET /api/v1/bff/investments` with `currency` and `secondary` params, `staleTime: 30_000`.
- **`PortfolioTab`** (`components/pages/investments/PortfolioTab.tsx`): Positions `DataTable` with signed P&L, holding links to `/investments/holdings/[id]`, asset allocation `CompositionBar` and `LegendList`.
- **`EvolutionCard`** (`components/pages/investments/EvolutionCard.tsx`): Portfolio value evolution `AreaChart` with dashed comparison line for cost basis.
- **`OperationsTab`** (`components/pages/investments/OperationsTab.tsx`): Recent operations scroll table inferred from positions.
- **`AlertsRail`** (`components/pages/investments/AlertsRail.tsx`): Portfolio market alerts.
- **`PositionDetail` & Route** (`components/pages/investments/PositionDetail.tsx` & `app/(dashboard)/investments/holdings/[id]/page.tsx`): Rebuilt holding detail route rendering price history `AreaChart` with axes and KPIs.
- **`InvestmentsContent`** (`components/pages/investments/InvestmentsContent.tsx`): Page composition root with `MarketStrip` (riesgo país rendered as points delta, e.g. `−12 pts`), `KpiStrip` and `Tabs` bound to `nuqs`.
- **i18n**: Added `investments` namespace to `messages/es-AR.json` and `messages/en.json`.

---

## Test Results

```
Test Files  38 passed (38)
     Tests 123 passed (123)  ← 0 skipped
  Duration  3.26s
```

## Verification

| Check | Result |
|---|---|
| Unit gate | ✅ `InvestmentsContent.test.tsx`, `PositionDetail.test.tsx` and `useInvestmentsPage.test.tsx` green |
| Types | ✅ `npx tsc --noEmit` 0 errors |
| i18n | ✅ `npm run i18n:check` exit 0 (41 keys) |
| Riesgo país unit | ✅ Formatted as points delta (`−12 pts`), not percentage |
| Chart fidelity | ✅ Price vertices match prices array length |
