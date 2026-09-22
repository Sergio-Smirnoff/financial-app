# Development Report — Wave 3 · Plan 04 — Components Tier 3 + Tier 4

**Branch:** `feat/wave3-components-tier34`  
**Date:** 2026-08-09  
**Repo:** `front/financial-app`  
**Status:** ✅ Complete — merged to `develop`

---

## What was built

### Tier 3 — Table & List Infrastructure (Task 1–2)

| Component | File | Notes |
|---|---|---|
| `DataTable` | `components/ui-kit/table/DataTable.tsx` | Headless table based on `@tanstack/react-table/legacy` + `@tanstack/react-table/flex-render`, `<th scope="col">`, `aria-sort` headers |
| `ScrollTable` | `components/ui-kit/table/ScrollTable.tsx` | Sticky header rail table (`position: sticky`, `maxHeight` prop) |
| `Pagination` | `components/ui-kit/table/Pagination.tsx` | Page control with previous/next buttons |
| `BulkActionBar` | `components/ui-kit/table/BulkActionBar.tsx` | Live region (`role="status"`) announcing selected count and actions |
| `ListRow` | `components/ui-kit/row/ListRow.tsx` | Atomic list item with title, subtitle, icon, right action slot |
| `DueRow` | `components/ui-kit/row/DueRow.tsx` | Expiration row showing due date, label, money figure |
| `ProgressRow` | `components/ui-kit/row/ProgressRow.tsx` | Clamped 100% visual bar, `.n` class for figures, `data-over="true"` when > 100% |
| `StatusDot` | `components/ui-kit/row/StatusDot.tsx` | Dot indicator + mandatory `label` (`.status-dot` token class) — tone never only signal |
| `DetailList` | `components/ui-kit/row/DetailList.tsx` | Structured `<dl>` key-value definition list |

### Tier 3 — Command Palette & Controls (Task 3–4)

| Component | File | Notes |
|---|---|---|
| `SearchBar` | `components/ui-kit/controls/SearchBar.tsx` | Command palette (cmdk), ⌘K shortcut listener, debounced 250ms query callback, grouped results |
| `Toolbar` | `components/ui-kit/controls/Toolbar.tsx` | Action toolbar with left/right slots |
| `ToggleRow` | `components/ui-kit/controls/Toolbar.tsx` | Settings row: label, description, and accessibility-linked `Switch` |
| `SaveBar` | `components/ui-kit/controls/Toolbar.tsx` | Sticky footer region for unsaved form changes |
| `FreshnessStamp` | `components/ui-kit/data/FreshnessStamp.tsx` | `observedAt` distance in `es-AR` (`date-fns`), `data-stale="true"` when age > 60m |
| `FeeTable` | `components/ui-kit/data/FeeTable.tsx` | Fee & commission schedule powered by `ScrollTable`, includes IVA treatment column |

### Tier 4 — Page-Specific Cards (Task 5)

| Component | File | Notes |
|---|---|---|
| `AccountCard` | `components/ui-kit/page/banks/AccountCard.tsx` | Bank account card with balance and currency |
| `CreditCardCard` | `components/ui-kit/page/banks/CreditCardCard.tsx` | Credit card card with closing cycle and limit usage progress bar (`role="progressbar"`) |
| `MarketStrip` | `components/ui-kit/page/investments/MarketStrip.tsx` | Scrollable strip of `QuotePill`s with freshness stamp |
| `StockBar` | `components/ui-kit/page/investments/StockBar.tsx` | Holding row with ticker, units, cost basis, currentValue, and `DeltaBadge` |
| `QuotePill` | `components/ui-kit/page/investments/QuotePill.tsx` | Ticker variation badge (`RIESGO_PAIS` rendered as absolute points delta, e.g. `−12 pts`) |
| `PositionForm` | `components/ui-kit/page/investments/PositionForm.tsx` | Add/edit position form UI shell |
| `AlertMark` | `components/ui-kit/page/investments/AlertMark.tsx` | Icon + text label alert marker |
| `Stepper` | `components/ui-kit/page/imports/Stepper.tsx` | Import wizard step indicator (`aria-current="step"`) |
| `Dropzone` | `components/ui-kit/page/imports/Dropzone.tsx` | File drag & drop zone with format rejection alert (`role="alert"`) |
| `FileProgress` | `components/ui-kit/page/imports/FileProgress.tsx` | File import status and upload progress bar (`role="progressbar"`) |

### Gallery & Documentation (Task 6)

- `app/design-preview/sections/tier34.tsx` created for live demonstration of all Tier 3+4 components.
- `front/financial-app/.ai/references/ROUTES.md` updated with `components/ui-kit/` design system tree.

---

## Test Results

```
Test Files  28 passed (28)
     Tests  87 passed (87)  ← 0 skipped
  Duration  4.17s
```

## Verification

| Check | Result |
|---|---|
| `npx vitest run components/ui-kit` | ✅ 61/61 green |
| `npx tsc --noEmit` | ✅ 0 errors |
| `npm run i18n:check` | ✅ exit 0 (20 keys) |
| Hand-rolled tables check | ✅ 0 matches outside `components/ui-kit/table/` |
