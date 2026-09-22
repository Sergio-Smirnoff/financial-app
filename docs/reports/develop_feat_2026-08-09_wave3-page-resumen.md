# Development Report — Wave 3 · Plan 06 — Resumen Page (`/`)

**Branch:** `feat/wave3-page-resumen`  
**Date:** 2026-08-09  
**Repo:** `front/financial-app`  
**Status:** ✅ Complete — merged to `develop`

---

## What was built

- **`useOverviewPage` Hook** (`lib/hooks/useOverviewPage.ts`): Single query hook consuming `GET /api/v1/bff/overview` with `currency` and `secondary` params, `staleTime: 30_000`.
- **`KpiRow`** (`components/pages/overview/KpiRow.tsx`): 4 KPI tiles (Efectivo, Ingresos, Gastos, Comprometido) wrapped in `SectionState`.
- **`NetWorthHero`** (`components/pages/overview/NetWorthHero.tsx`): Net worth evolution hero card rendering `AreaChart`, delta badge, and `★ Máximo histórico` badge when applicable.
- **`BreakdownCard`** (`components/pages/overview/BreakdownCard.tsx`): Asset allocation breakdown using `CompositionBar`.
- **`FlowCard`** (`components/pages/overview/FlowCard.tsx`): Monthly income vs expenses bar pair chart using `BarPairChart`.
- **`CommittedCard`** (`components/pages/overview/CommittedCard.tsx`): Monthly committed expenses using `HorizonBars`.
- **`UpcomingRail`** (`components/pages/overview/UpcomingRail.tsx`): Upcoming due dates list rendering `DueRow`s linked to `/banks`.
- **`SpendByCategoryCard`** (`components/pages/overview/SpendByCategoryCard.tsx`): Category expenses breakdown rendering `ProgressRow`s.
- **`LatestMovementsCard`** (`components/pages/overview/LatestMovementsCard.tsx`): Recent transactions scrollable table rendering `ScrollTable` with empty state action.
- **`OverviewContent`** (`components/pages/overview/OverviewContent.tsx`): Page composition root utilizing `SplitLayout` and `FreshnessStamp`.
- **Dashboard Home Rewrite** (`app/(dashboard)/page.tsx`): Bound to `nuqs` (`?currency=`, `?secondary=`) and serving `<OverviewContent />`.
- **Legacy Cleanup**: Deleted legacy `components/pages/dashboard/*`, `lib/api/dashboard.ts`, and `lib/hooks/useDashboard.ts`.
- **i18n**: Added `overview` namespace to `messages/es-AR.json` and `messages/en.json`.

---

## Test Results

```
Test Files  30 passed (30)
     Tests  94 passed (94)  ← 0 skipped
  Duration  4.17s
```

## Verification

| Check | Result |
|---|---|
| Unit gate | ✅ `OverviewContent.test.tsx` and `useOverviewPage.test.tsx` green |
| Types | ✅ `npx tsc --noEmit` 0 errors |
| i18n | ✅ `npm run i18n:check` exit 0 (26 keys) |
| One query | ✅ `getOverview` called exactly once per query state |
| Legacy cleanup | ✅ `grep -rn "useDashboard"` 0 matches |
