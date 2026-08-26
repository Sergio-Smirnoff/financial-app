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

### Process rule — live verification (Wave 3.5 Round D, 2026-08-23)
- **No wave may report a live-verification goal `met` without pasted run output.** Wave 3.5
  closed on unit tests + drift gate alone; the first real run failed 8/8. The procedure lives
  in `front/financial-app/README.md` (`npm run e2e:live`). `[process]`

### Tech-debt — found during Wave 3.5 Round D (2026-08-23)
- Gateway `FinancesGatewayImpl.fetchTransactions` cannot page or filter: ms-finances
  `TransactionController` accepts `cursor`/`size` (no `page`), and the `categories`/`accounts`
  filters are accepted by the gateway signature but never forwarded. The BFF page section
  works only because the default window fits one response. `[bug]` `[tech-debt]`
- ~~`npx tsc --noEmit` reports ~303 pre-existing errors in `front/financial-app`~~ —
  superseded by the Wave 4 Round A entry below: down to 142 after the dead-code purge, and no
  longer silent (they now fail `next build`). `[tech-debt]`
- IOL market data is unavailable in local development; the investments `marketStrip` is
  correctly `UNAVAILABLE` offline. If a local fixture upstream is ever wanted, it belongs in
  ms-investments, not the gateway. `[infra]`
- The `frontend` compose service serves a stale published image (built pre-redesign) and
  holds port 3000; the live-smoke procedure stops it. Decide in Wave 4 whether to rebuild it
  in CI or drop it from the `app` profile. `[infra]` `[tech-debt]`

### Tech-debt — found during Wave 4 Round A (2026-08-23)
- ~~`lib/hooks/__tests__/useOverviewPage.test.tsx:76` trips `react/display-name`~~ — fixed
  2026-08-23 (named the wrapper component; in the front working tree, pending commit). With
  lint clear, `npm run build` now advances to type-check and fails there — see the tsc entry
  below. `[bug]` `[front]`
- ~~`npx tsc --noEmit` in `front/financial-app` is down to **142 errors (83 outside
  tests/design-preview)**, no longer silent — `next build` reaches its type-check stage and
  fails on them; red on develop since 2026-08-09~~ — **done 2026-08-23** on
  `fix/wave4-tsc-remediation`: 142 → **0**, `npm run build` green (14/14 pages), 157/157 tests,
  zero suppressions. Report: `docs/reports/develop_fix_2026-08-23_wave4-tsc-remediation.md`.
  `[bug]` `[tech-debt]` `[front]`
- `npm run typecheck` (`tsc --noEmit`) now exists in `front/financial-app` and is green, but
  **nothing enforces it** — only `next build` would catch a regression, and only at merge time.
  Wiring it into the front CI workflow is a plan-12 question. `[infra]` `[front]`
- ~~`tsconfig.tsbuildinfo` is tracked in git in `front/financial-app`~~ — done 2026-08-23:
  gitignored and `git rm --cached` (`c8a8787`). `[tech-debt]` `[front]`
- Loan KPIs assume every loan is ARS: `GetLoansBffUseCaseImpl.toKpis`, the Bancos
  `loanBalance` KPI and Overview `breakdown.debt` sum amounts across loans and convert the
  total from `Currency.ARS`, but ms-banks loans carry a `currency` field and USD loans are
  creatable today — a mixed-currency portfolio misreports the totals. Same for
  `GetLoanScheduleBffUseCaseImpl`, which converts installment amounts from ARS without
  fetching the loan row. Needs a real multi-currency sum before the Préstamos page (plan 10)
  ships mixed-currency data. `[bug]` `[gateway]`

#### Found during Wave 4 plan 03b — tsc remediation (2026-08-23)

- `components/pages/categories/BudgetTab.tsx:37` reads `cat.cap.amount`, but the schema types
  `BudgetRowResponse.cap` as a bare `number` — the read is always `undefined`, so every budget
  renders "Sin límite" and the progress bar never appears. Hidden by the pre-existing
  `(cat: any)` on line 35. `[bug]` `[front]`
- Double error toast on a failed account create: `useAccounts.onError` toasts and
  `AddAccountDialog`'s `catch` toasts, and `mutateAsync` fires both. Pick one place to report
  mutation errors. `[ux]` `[front]`
- "Agregar cuenta" is reachable **only** as the accounts empty-state action — a user who
  already has accounts has no affordance to open the dialog. The dialog's edit path
  (`onUpdate`) is dead for the same reason: nothing ever passes it an `account`. `[ux]` `[front]`
- Invented-zero fallbacks still remain at `AccountsTab:49`, `CardsTab:45` and
  `CashDistributionCard:17` — they need `AccountCard.balance` / `CompositionBar` prop widenings
  so a missing amount renders the em-dash placeholder instead of `$0,00`. `[tech-debt]` `[front]`
- Live `any` sweep for the front: `(e: any)` ×3 in `lib/hooks/useBanks.ts` (onError), plus
  `as any` in tests — `ImportsContent` ×2, `TransactionsContent`, `OverviewContent`,
  `InvestmentsContent` ×4. `[tech-debt]` `[front]`
- **`app/design-preview/page.tsx` is orphaned** — it renders an empty placeholder `<div>` and
  nothing imports the `sections/tier12`, `tier34` or `charts` modules, although
  `sections/README.md` claims they are rendered there. Needs wiring before Round B eyeballs it.
  Two defects behind it: `middleware.ts` matches public paths by exact equality, so any
  `/design-preview/*` sub-route redirects to `/login`; and the `FreshnessStamp` demos always
  render the stale branch now that their timestamps are fixed instants. `[bug]` `[front]`
- `CreditCardCardData` models closing and due days as two bare unvalidated `number`s — a
  reification gap against the repo's VO conventions. Separately, `AddAccountDialog` defaults
  `currency` to `USD` on an ARS-first product. `[tech-debt]` `[front]`

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
