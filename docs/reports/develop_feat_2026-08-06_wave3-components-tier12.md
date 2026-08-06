# Development Report — Wave 3 · Plan 03 — Components Tier 1 + Tier 2

**Branch:** `feat/wave3-components-tier12`  
**Date:** 2026-08-06  
**Repo:** `front/financial-app`  
**Status:** ✅ Complete — merged to `develop`

---

## What was built

### Tier 1 — Money & Feedback (Task 1–2)

| Component | File | Notes |
|---|---|---|
| `Money` | `components/ui-kit/money/Money.tsx` | Tabular numerals (`.n`), gain/loss tone, secondary currency |
| `DeltaBadge` | `components/ui-kit/money/DeltaBadge.tsx` | `+`/`−` glyph, optional absolute value, colour never the only signal |
| `SectionState<T>` | `components/ui-kit/feedback/SectionState.tsx` | Consumes `useSection`; four-state matrix (loading/unavailable/empty/ready) |
| `InlineBanner` | `components/ui-kit/feedback/InlineBanner.tsx` | 4 tones (info/warn/error/success), icon + close |
| `Toast` | `components/ui-kit/feedback/Toast.tsx` | `role="status"`, 4 tones |

**Legacy retired:** `QueryBoundary`, `ErrorMessage`, `LoadingSpinner` — all call sites migrated.

### Tier 1 — Shell (Task 3)

| Component | File | Notes |
|---|---|---|
| `AppShell` | `components/ui-kit/shell/AppShell.tsx` | TopBar + SideNav + content; wires `NotificationBell` slot |
| `TopBar` | `components/ui-kit/shell/TopBar.tsx` | Named slots: `searchSlot` (plan 04), `currencySlot` (plan 04), `notificationSlot` |
| `SideNav` | `components/ui-kit/shell/SideNav.tsx` | `aria-current="page"`, `data-slot="rail"`, `md:w-60`, next-intl `nav` namespace |
| `MobileSideNav` | `components/ui-kit/shell/SideNav.tsx` | Drawer variant, triggered by `useUiStore.toggleSidebar` |
| `SideNavItem` | `components/ui-kit/shell/SideNavItem.tsx` | Atomic link with `aria-current` |

**Dashboard layout** (`app/(dashboard)/layout.tsx`) now delegates to `AppShell`. All 7 page files migrated off `<Header>`. Old `Header.tsx`, `Sidebar.tsx`, `MobileSidebar.tsx` deleted.

### Tier 1 — Overlay & Notifications (Task 4)

| Component | File | Notes |
|---|---|---|
| `Dialog` | `components/ui-kit/overlay/Dialog.tsx` | Required `description` prop → `aria-describedby` structurally impossible to omit (IDEAS.md fix) |
| `SidePanel` | `components/ui-kit/overlay/SidePanel.tsx` | Non-modal; Escape closes + focus returns to trigger |
| `NotificationBell` | `components/ui-kit/notifications/NotificationBell.tsx` | `role="status"` on unread badge; opens `NotificationList` |
| `NotificationList` | `components/ui-kit/notifications/NotificationList.tsx` | Consumes existing `useNotificationSSE` hook untouched; dropdown + full mode |

`ConfirmDialog` rebuilt to delegate to `Dialog` (keeps public name).  
Old `NotificationDialog`, `NotificationDropdown`, `NotificationBell` in `components/layout/` deleted.

### Tier 2 — Layout & Controls (Task 5)

| Component | File | Notes |
|---|---|---|
| `KpiTile` | `components/ui-kit/layout/KpiStrip.tsx` | `.elev-sm`, `.kicker` label, `.n` value, optional delta |
| `KpiStrip` | same | 2-col → 4-col responsive grid |
| `RailSection` | same | `.section-head` + `.fade-rule` |
| `SplitLayout` | same | Rail after main in DOM (tab order = content first) |
| `FilterBar` | `components/ui-kit/controls/FilterBar.tsx` | `onClear`, wraps `FilterChip`s |
| `FilterChip` | same | `.tag-accent`, keyboard-removable (Enter/Space), `aria-label` |
| `RowActions` | same | Radix DropdownMenu, `data-tone="destructive"` on destructive items |

### Gallery & Docs (Task 6)

- `app/design-preview/sections/tier12.tsx` — all 16 components in all states (did NOT touch `page.tsx`)
- `components/ui-kit/index.ts` — barrel export for the entire library

---

## Test results

```
Test Files  9 passed (9)
     Tests  34 passed (34)  ← 0 skipped
  Duration  2.4s
```

## Verification

| Check | Result |
|---|---|
| `npm run test:run -- components/ui-kit` | ✅ 34/34 green |
| `npx tsc --noEmit` | ✅ no errors |
| `ls components/shared/QueryBoundary.tsx components/layout/Sidebar.tsx` | ✅ both missing |
| Legacy components deleted | ✅ Header, Sidebar, NotificationDialog, NotificationDropdown, NotificationBell (layout/) |

---

## Token constraints respected

- `.n` (tabular numerals) on all money figures and KpiTile values
- `.kicker` on tile and section labels
- `.section-head` / `.fade-rule` on rail sections
- `.elev-sm` on KpiTile, `.elev-md` on SidePanel + NotificationBell popup
- `.tag-accent` on FilterChip
- `.status-dot` on unread notification marker
- No blur, no `glass` variant, no invented utilities
- Colour never the only signal: `+`/`−` glyphs on Delta, `aria-label` on status dots, text beside every signal
