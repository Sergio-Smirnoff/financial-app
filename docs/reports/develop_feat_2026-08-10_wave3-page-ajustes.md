# Development Report — Wave 3 · Plan 12 — Ajustes Page (`/settings`)

**Branch:** `feat/wave3-page-ajustes`  
**Date:** 2026-08-10  
**Repo:** `front/financial-app`  
**Status:** ✅ Complete — merged to `develop`

---

## What was built

- **`useSettingsPage` Hook** (`lib/hooks/useSettingsPage.ts`): Query hook consuming `GET /api/v1/bff/settings` with staleTime 30_000.
- **`ProfileSection`** (`components/pages/settings/ProfileSection.tsx`): User profile details and editable name form.
- **`SecuritySection`** (`components/pages/settings/SecuritySection.tsx`): Active sessions list with current session indicator and confirmation dialog (`AlertDialog`) for revoking other sessions, plus change password form.
- **`CurrencyFormatSection`** (`components/pages/settings/CurrencyFormatSection.tsx`): Secondary currency display preference (separate from TopBar `?currency=`), live number format preview (`$ 1.284.000`), and positive/negative figure color preferences.
- **`NotificationsSection`** (`components/pages/settings/NotificationsSection.tsx`): Category notification toggles, maintaining combined `PAYMENT_DUE` toggle.
- **`FeesSection`** (`components/pages/settings/FeesSection.tsx`): Bank/card/broker fee schedules using `FeeTable` with IVA treatment labels and debit/credit tax rate indicator.
- **`DataSection`** (`components/pages/settings/DataSection.tsx`): CSV export and account deletion controls rendered as disabled affordances with "Próximamente" badge.
- **`SettingsContent`** (`components/pages/settings/SettingsContent.tsx`): Composition root with left nav scroll-spy links and sticky `SaveBar` footer on form dirty state.
- **Ajustes Page Rewrite** (`app/(dashboard)/settings/page.tsx`): Serving `<SettingsContent />` with nuqs parameters.
- **i18n**: Added `settings` namespace to `messages/es-AR.json` and `messages/en.json`.

---

## Test Results

```
Test Files  44 passed (44)
     Tests 142 passed (142)  ← 0 skipped
  Duration  3.26s
```

## Verification

| Check | Result |
|---|---|
| Unit gate | ✅ `SettingsContent.test.tsx` and `useSettingsPage.test.tsx` green |
| Types | ✅ `npx tsc --noEmit` 0 errors |
| i18n | ✅ `npm run i18n:check` exit 0 (51 keys) |
| Two concepts | ✅ Secondary currency preference separated from `?currency=` view |
| Combined PAYMENT_DUE toggle | ✅ Single combined toggle maintained |
