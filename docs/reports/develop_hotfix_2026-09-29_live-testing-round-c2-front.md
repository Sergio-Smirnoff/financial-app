# Live-testing Round C2 front and gateway contract fixes

## Branches and repositories involved

| Repository | Branch | Base |
|---|---|---|
| `front/financial-app` | `hotfix/live-testing-round-c2` | `develop` @ `0147e22` |
| `back/ms-gateway` | `hotfix/live-testing-round-c2` | `develop` @ `080a93d` (includes C1) |
| parent `financial-app` (worktree `../financial-app-round-c2`) | `hotfix/live-testing-round-c2` | `develop` @ `57fcd61` (includes C1) |

Read only, not changed: `back/ms-users` (`SessionController`, `SessionResponse`), `back/ms-finances` (`CategorizationRuleResponse`, transaction query). The branches are **not merged, not pushed, not released**. Production is still on v1.3.0. Tasks 13 (merge to `develop` locally) and 14 (PRs, release, deploy, live checks) are the user's calls and have not happened.

## Objective

Make the movements page trust the URL (search, page and a new multi-category filter survive deep links, paging and other filter changes), make `npm run e2e:live` pass again, and replace the gateway's two sourceless BFF fields: rules show `matchCount` instead of an always-null `priority`, sessions drop `ip` and finally report which one is `current`.

## Connection to plans or specs

- Plan: `docs/superpowers/plans/2026-09-29-live-testing-round-c2-front.md` (no separate spec).
- Follows Round C1: `docs/reports/develop_hotfix_2026-09-28_live-testing-round-c1-backend.md`. Closes its routed items C1-D3 (rule priority), C1-D4 (session ip) and C1-D11 (sessions never `current`).
- Part A of `docs/superpowers/specs/2026-09-28-one-screen-layout-design.md` branches from `develop` after this round merges (shared `TransactionFilters`/`SearchBar` code).
- User ruling 2026-09-29 (explicit R15 approval): remove BFF `RuleRow.priority` (replaced by `matchCount`) and `SessionRow.ip`. Plan Decisions D1-D9 were not answered by the user, so the plan defaults are in force (see Follow-ups).

## Diagrams

```mermaid
flowchart LR
    subgraph Before["before: develop @ 0147e22"]
        SB["SearchBar (omnibar) useState('')"] -- "useEffect every render" --> W1["setQ / setPage('1')"]
        W1 --> URL1[("URL ?q=&page=")]
    end
    subgraph After["after"]
        P["transactionFilterParams: q, categories[], accounts, method, page:int"]
        FSF["FilterSearchField (controlled)"] --> TF2["TransactionFilters useQueryStates"]
        MSF["MultiSelectFilter"] --> TF2
        TF2 --> URL2[("URL ?q=&categories=none,1106&page=")]
        TC2["TransactionsContent useQueryStates"] --> URL2
        P --> TF2
        P --> TC2
    end
```

```mermaid
sequenceDiagram
    participant B as Browser (cookie access_token)
    participant C as SettingsBffController
    participant U as GetSettingsBffUseCaseImpl
    participant G as UsersGatewayImpl
    participant M as ms-users SessionController
    B->>C: GET /api/v1/bff/settings
    C->>U: execute(UserId, Optional<AccessToken>)
    U->>G: fetchSessions(UserId, Optional<AccessToken>)
    G->>M: GET /me/sessions (X-User-Id + cookie only when present)
    M-->>G: rows with current = sid of that token
    G-->>U: rows
    U-->>C: SessionRow(id, device, lastSeenAt, current)
    C-->>B: exactly one current=true
```

```
Round C2
├── front/financial-app   7 commits   G1 G2 G3 G4 G5 G6
├── back/ms-gateway       4 commits   G4 G5 G6
└── parent                2 commits   IDEAS + this report
```

## Goals

Statuses reflect local evidence only. **No live check (LC1-LC4) has run: they need production after the user deploys (Task 14).** Every goal that names an LC check is therefore `partial`, and its missing part is that live check.

| Goal | Status | Evidence / what is missing |
|---|---|---|
| G1 | partial | Local half met: front 277/277 including `keeps a deep-linked search and page untouched on mount`, `stays on the page it moves to`, and the e2e `Movimientos keeps a deep-linked search and filters by several categories` (passed, Task 8 Step 3). Missing: LC1 on prod. |
| G2 | partial | Local half met: `MultiSelectFilter`/`TransactionFilters` tests green; Task 8 union check `categories=none,1109` gave total 1 = 0 (`categories=1109`) + 1 (`categories=none`). **Weak evidence: the Supermercado id used (1109) has 0 movements, so 1 = 0 + 1 holds arithmetically but does not exercise a union of two non-empty sets.** Missing: LC2 on prod. |
| G3 | met | `npm run e2e:live` printed `10 passed (22.4s)` (Task 8 Step 3, below), on the local DB that still holds duplicate demo categories. The front README procedure reaches the gateway (dev overlay). |
| G4 | partial | Gateway `mvn clean verify` 187/0/0 (`CategoriesBffTest` rule cases); front 277/277 (`shows how many movements each rule has categorised, and no priority`); Task 8 rules check gave `matchCount` int, `hasPriority: false`. Only one demo rule (COTO to Supermercado, created locally, matchCount 0), so the value shown was 0. Missing: LC3 on prod. |
| G5 | partial | Gateway tests green (`UsersGatewayImplTest`, `SettingsBffTest`, `BffRouteTest` cookie cases, 187/0/0); `SecuritySection.test.tsx` both new tests green; Task 8 sessions check `{"current": 1, "hasIp": false}`; e2e `Ajustes` passed. Missing: LC4 on prod. |
| G6 | met | Task 6 Step 1 diff shows exactly the three contract changes (plus one ruled cosmetic `servers` line, below); `npm run bff:check` exit 0; typecheck clean; fixture has no `ip` and one current session. |

Goals restated verbatim from the plan:

- **G1. On `/transactions` the URL is the single source of truth. A deep link with `q`, `categories` and `page` renders with those filters and is not rewritten. "Página siguiente" moves to the next page and stays. Changing one filter never clears another. The page stops writing the URL once idle.** Status: partial.
- **G2. Movements can be filtered by several categories at once, "Sin categorizar" included, through a ui-kit multi-select. The selection is in the URL as `categories=none,<id>,…`, each selected category is one removable chip (also one the options no longer list), and the BFF receives the same list and returns their union.** Status: partial.
- **G3. `npm run e2e:live` passes 10/10 against the local stack seeded by `scripts/seed-demo-user.sh`, including on a DB that still holds duplicate demo categories, with the procedure in the front README reaching the gateway.** Status: met.
- **G4. The Rules tab shows how many movements each rule has categorised (`matchCount` from ms-finances) instead of an always-0 priority. A rules payload without `matchCount` renders the rules section `UNAVAILABLE`.** Status: partial.
- **G5. The Settings sessions list marks exactly the session making the request as current, with no revoke button on it. No other row is marked. Without the cookie none is, and the route still answers.** Status: partial.
- **G6. The BFF contract the front compiles against matches the gateway. `openapi/gateway.json` differs from `develop` by exactly `RuleRowResponse.matchCount`, the removed `SessionRowResponse.ip`, and the optional settings cookie parameter. `npm run bff:check` passes and no session `ip` or rule `priority` remains in front code, fixtures or catalogues.** Status: met, with one stated addition: the generated spec also flipped `servers[0].url` from 8090 to 8080 (ruling below).

## What was done

- **Front T1:** ui-kit `FilterSearchField` (controlled, stateless) and `MultiSelectFilter` (checkbox dropdown), exported from `components/ui-kit/index.ts`.
- **Front T2:** one parser map `transactionFilterParams.ts` bound by `TransactionFilters` and `TransactionsContent` via `useQueryStates`; multi-category filter with removable chips (including ids the options no longer list); `useTransactionsPage` keeps previous data during refetch; `SearchBar` is now omnibar-only (no props); `design-preview` `tier34` updated; catalogue keys added in `es-AR` and `en`.
- **Front T3:** live smoke selectors scoped (Bancos loan name, Categorias budget row), new Movimientos deep-link journey, README procedure fixed (gateway needs the dev overlay).
- **Gateway T4:** `RuleRow.matchCount` (strict read), `SessionRow` without `ip`, mapper and both use cases updated.
- **Gateway T5:** `Optional<AccessToken>` from `SettingsBffController` (`@CookieValue(required = false)`) through the use case and `UsersGateway.fetchSessions`; the adapter adds the `access_token` cookie only when present; `SessionRow.current` is a strict read.
- **Front T6:** rebuilt gateway, regenerated `openapi/gateway.json` and `lib/api/bff/schema.d.ts`; Rules tab shows `timesApplied` column from `matchCount`; fixtures drop `ip`.
- **Front T7:** `SecuritySection` marks only `s.current === true`; the first-row fallback is gone.
- **T8:** local integration, no commits (evidence below). **T9:** whole-branch review, then a fix wave (`AccessToken.toString` redaction with test, dead `vi.mock` removed). **T10:** gateway DDD audit, clean. **T11:** R18 docs and IDEAS.

## Problems found

- **Endless URL writes and a broken pager.** `TransactionFilters` embedded the global omnibar `SearchBar`, whose `useEffect` ran on every render and wrote `setQ(query || null); setPage('1')`. A vitest harness measured 80+ URL writes of `""` in 200 ms at `?q=cafe&page=3`; live, `/transactions?q=Coto&page=2` settled on `/transactions` and "Página siguiente" snapped back. Fixed by removing the omnibar from the page and binding all keys to one parser map.
- **`e2e:live` failed 2/9** (strict-mode violations): Bancos `getByText('Préstamo personal')` matched the loans table and the calendar rail; Categorias `budget-row` filtered by `Supermercado` matched 22 to 23 rows because of duplicate demo categories. Fixed by scoping the selectors (Task 3).
- **First-row current fallback.** `SecuritySection` marked the first session current when none was, which masked C1-D11 and hid the revoke button on a probably-wrong session. Removed (Task 7).
- **Dirty local DB.** 21 duplicates each of `Supermercado`, `Transporte`, `Sueldo` from pre-C1 seed runs. Not cleaned (R15, D4); selectors tolerate them. Task 3 left a `.first()` on the Supermercado menu item as a workaround (`live-smoke.spec.ts:87`) to drop after a DB reset.
- **Portless gateway.** The base compose publishes no host port for the gateway; the front README procedure was stale. Fixed in README; the dev overlay is used, and after Task 8 the gateway was recreated without the host port. The local `:latest` gateway image is now this branch's build.
- **Task 5 review:** default `AccessToken.toString()` would print the raw JWT (latent leak). Fixed in the fix wave (`2ac61d9`).
- **Task 6 ruling:** the regenerated `openapi/gateway.json` also flipped `servers[0].url` 8090 to 8080 (the dump script default; the earlier snapshot used an override). Accepted as generated; hand-editing is forbidden.
- **Task 10 DDD audit:** clean, 0 introduced; `LayeredArchitectureTest` 3/3. Four pre-existing items routed to IDEAS: Spring `@Service`/`@Autowired` in application impls; untyped `Map` payloads on outbound ports; the `"access_token"` literal repeated (this round added two copies, `SettingsBffController:36` and `UsersGatewayImpl:29`); boxed `Boolean`/`Integer` on `RuleRow`/`SessionRow`.
- **Task 9 final review (opus):** merge-ready, 0 Critical, 0 Important, 3 minors: `UncategorisedBanner` hard-codes its `categories=none` href; duplicate or blank category ids in a hand-edited URL give a duplicate React key; dead `vi.mock` of search in `TransactionFilters.test.tsx:11` (fixed in `4444318`).
- **Evidence gaps in the ledger:** Task 1 wrote the implementation before a RED run (no RED captured); Task 4 had no separate RED run; Task 3 reported a named list of 10 tests and no raw output (Task 8 re-ran and pasted it).
- **Ledger rulings (all of them):**
  - Task 6: accept the `servers[0].url` 8090 to 8080 flip as a 4th generated change. Cost if wrong: one cosmetic line in the generated spec.
  - Final: open one small fix wave for `AccessToken.toString` redaction (+ test) and the dead `vi.mock`; everything else to IDEAS. Cost if wrong: two tiny extra commits.
  - Task 11: route D1/D2/D4/D5/D7/D8 to IDEAS as plan defaults, since the user has not answered the Decisions table. Cost if wrong: the user promotes one to a follow-up.

## Files and commits touched

| Repo | Branch | Commit |
|---|---|---|
| front/financial-app | `hotfix/live-testing-round-c2` | `ac96ac3` feat(front): add filter search and multi-select |
| front/financial-app | same | `1f8b4d8` fix(front): bind movement filters to the URL |
| front/financial-app | same | `a59bc1a` test(front): harden live smoke selectors |
| front/financial-app | same | `dfac999` fix(front): adopt matchCount, drop session ip |
| front/financial-app | same | `4bd3977` fix(front): mark only the real current session |
| front/financial-app | same | `4444318` fix(front): address branch review findings |
| front/financial-app | same | `25e7aaf` docs(front): record URL filters and sessions |
| back/ms-gateway | `hotfix/live-testing-round-c2` | `0fb4fb2` fix(gateway): rule matchCount, no session ip |
| back/ms-gateway | same | `071b4f6` fix(gateway): forward access token for sessions |
| back/ms-gateway | same | `2ac61d9` fix(gateway): address branch review findings |
| back/ms-gateway | same | `07e4888` docs(gateway): record matchCount and sessions |
| parent (worktree) | `hotfix/live-testing-round-c2` | `13b4e25` docs: route round C2 follow-ups |
| parent (worktree) | same | (this report) docs: report live-testing round C2 |

## Verification evidence

Pasted from the SDD workspace (`.superpowers/sdd/2026-09-29-live-testing-round-c2-front/`, gitignored, main checkout). Not pasted as raw logs: the final gate tails exist only as the summary lines below (`final-fix-report.md`).

### Task 9 gates from clean (final fix wave)

```
Gateway mvn clean verify: BUILD SUCCESS, Tests run: 187, Failures: 0, Errors: 0, Skipped: 0
RED (fix wave): AccessTokenTest Tests run: 3, Failures: 1 - toStringDoesNotRevealTheToken:12 expected: <false> but was: <true>
GREEN: AccessTokenTest 3/3; TransactionFilters.test.tsx: 9 passed
Front: typecheck rc=0 silent; lint rc=0 warnings only; test:run Test Files 69 passed, Tests 277 passed (277);
       i18n OK - 684 keys; bff:check rc=0; next build succeeded
Scans: "no suppressions (front)", "en catalogue clean", "no suppressions or inline FQNs (gateway)"
```

Lint note: warnings only (`tier34` ScrollTable/QuotePill, `TransactionsContent` catId, `SearchBar` aria) and other pre-existing ones in files with empty diff vs `develop` (`SidePanel.test`, `Banks.test`); warnings in touched files are identical to `develop`. No lint errors. The ms-gateway gate is `mvn verify` (no JaCoCo plugin, so no coverage gate is claimed).

### OpenAPI diff (Task 6 Step 1)

`jq -S` diff of `openapi/gateway.json` against `develop` (gateway rebuilt from the branch, 117 schemas) showed exactly three contract changes:

```
RuleRowResponse: priority -> matchCount
SessionRowResponse: ip removed
GET settings: gains optional access_token cookie parameter
```

plus the generated `servers[0].url` 8090 to 8080 flip (ruling above). `npm run bff:types` regenerated `schema.d.ts`; `npm run bff:check` exit 0. Front suite 275 passed at that commit.

### Curl checks (Task 8 Step 2, verbatim)

```
Login successful
{ "status": "OK", "current": 1, "hasIp": false }
{ "status": "OK", "sample": null, "hasPriority": false }      <- rules empty on first run
CAT=1109
{ "status": "OK", "total": 1 }        # categories=none,1109
0                                     # categories=1109 only
1                                     # categories=none only
```

Union: 1 == 0 + 1, pass (weak evidence: category 1109 has 0 movements). Rules were empty, so one rule was created for the local demo user:

```
POST /api/v1/finances/categorization-rules {"matchType":"CONTAINS","pattern":"COTO","categoryId":1109}
-> 201 {"id":1,"matchType":"CONTAINS","pattern":"COTO","categoryId":1109,"categoryName":"Supermercado","matchCount":0,...}
{ "status": "OK",
  "sample": { "id": 1, "matcher": "COTO", "categoryId": 1109, "categoryName": "Supermercado", "matchCount": 0 },
  "hasPriority": false }
```

The seed created nothing new (`verified:` lines for transactions (144), budgets (70), budget spend (329969), loans (1), import history (3), holding positions (2)).

### `npm run e2e:live` (Task 8 Step 3, full output)

```
Running 10 tests using 1 worker

  ✓   1 [live] › e2e/live-smoke.spec.ts:8:5 › Resumen renders composed KPIs and the flow chart (4.2s)
  ✓   2 [live] › e2e/live-smoke.spec.ts:16:5 › Bancos renders all seven sections with seeded entities (1.5s)
  ✓   3 [live] › e2e/live-smoke.spec.ts:25:5 › Movimientos renders the summary strip, rows and method filter (1.1s)
  ✓   4 [live] › e2e/live-smoke.spec.ts:32:5 › Movimientos keeps a deep-linked search and filters by several categories (1.4s)
  ✓   5 [live] › e2e/live-smoke.spec.ts:45:5 › Categorías flags the deliberately over-cap budget (1.1s)
  ✓   6 [live] › e2e/live-smoke.spec.ts:55:5 › Inversiones renders portfolio sections and degrades only the market strip (1.1s)
  ✓   7 [live] › e2e/live-smoke.spec.ts:61:5 › Importaciones lists the seeded run and its reconciliation (1.0s)
  ✓   8 [live] › e2e/live-smoke.spec.ts:68:5 › Ajustes renders profile, preferences, notifications, fees and sessions (1.4s)
  ✓   9 [live] › e2e/live-smoke.spec.ts:77:5 › global search returns a grouped movements hit (1.2s)
  ✓  10 [live] › e2e/live-smoke.spec.ts:84:5 › no route throws a client-side exception against live data (7.8s)

  10 passed (22.4s)
```

### Per-task test evidence

- T1: focused 7/7, tsc 0, full 262/262 (no RED captured).
- T2: RED TransactionFilters 8 failed, TransactionsContent 3 failed; GREEN 274/274, i18n 684 keys.
- T3: before 2 failed / 7 passed; after 10 passed.
- T4: gateway `mvn verify` 180/0/0. T5: RED compilation error captured; `mvn -o verify` 186/0/0.
- T6: RED `Unable to find role="columnheader" and name "Veces aplicada"`; 275/275. T7: RED 1 failed; 277/277.

**Not run:** LC1-LC4 (Task 14, needs production).

## Contract changes

- `RuleRowResponse.priority` removed, replaced by `matchCount` (int32). Domain `RuleRow.matchCount` is a strict read of ms-finances; a missing value makes the rules section `UNAVAILABLE`.
- `SessionRowResponse.ip` removed.
- `/bff/settings` documents an optional `access_token` cookie parameter; `SessionRow.current` is now true for the caller's session only and is a strict read (missing flag makes the sessions section `UNAVAILABLE`).
- Ports: `UsersGateway.fetchSessions(UserId, Optional<AccessToken>)` and `GetSettingsBffUseCase.execute(UserId, Optional<AccessToken>)`. `AccessToken.toString` is redacted.
- Front URL format: `categories` is a comma list (`categories=none,1106`); `page` is one integer parser shared by both components.
- Catalogue: `transactions.filters.search` and `transactions.filters.categoriesSelected` added; `categories.rules.priority` renamed to `categories.rules.timesApplied`.
- `SearchBar` takes no props.
- Generated `openapi/gateway.json` `servers[0].url` flipped 8090 to 8080 (cosmetic, ruled).
- No migrations, no Kafka schema changes, no ms-users or ms-finances changes. Front and gateway must ship together (an old front against the new gateway loses the rule count; a new front against an old gateway shows no `matchCount` and no current session).

## Follow-ups and deferred work

Routed to `docs/specs/IDEAS.md` (commit `13b4e25`, C2 section; the two `TransactionFilters.tsx:26` entries and the C1 sessions entry were removed as closed):

- D1 omnibar routing free text to `/transactions?q=`; D2 accent-insensitive search in ms-finances (`cafe` vs `Café`); D4 local demo DB duplicates (local-only reset is the user's call, R15) plus the COTO demo rule sentence; D5 parent category not including subcategories; D7 ms-users keeps every session (131 for the demo user); D8 debounce for search.
- Review and audit minors: `UncategorisedBanner` hard-coded href; duplicate or blank category ids in a hand-edited URL; the four T10 pre-existing DDD items (split into 3 entries); `Math.toIntExact` throwing `ArithmeticException` instead of a contract violation (unreachable); `MultiSelectFilter` untick removing all duplicate copies (unreachable via UI); `TransactionsContent.test.tsx:551` `release()` outside try/finally; `live-smoke.spec.ts:87` `.first()` workaround.
- **Task 11 Step 3 and its minors:** `UI_STATE.md` URL State row is missing a separator after `<NuqsAdapter>`, and the `keepPreviousData` note sits under the Zustand section. Left as is; fix in a docs touch-up.
- **Process (the user's):** Task 13, merge to `develop` locally; Task 14, PRs, release, deploy, then LC1-LC4 on production (which move G1, G2, G4, G5 from `partial` to `met`). Nothing was merged or pushed. Part A branches from `develop` after this round merges.

## Results

Local evidence is green: gateway 187/0/0, front 277/277, `i18n:check` 684 keys, `bff:check` exit 0, build ok, `e2e:live` 10 passed, final review merge-ready (0 Critical, 0 Important), DDD audit clean. G3 and G6 are met; G1, G2, G4, G5 are `partial` until the production live checks run after release and deploy. G2's local union check is weak (category with 0 movements). Nothing is merged, pushed or released.

## Other references

- Plan: `docs/superpowers/plans/2026-09-29-live-testing-round-c2-front.md`
- C1 report: `docs/reports/develop_hotfix_2026-09-28_live-testing-round-c1-backend.md`
- SDD workspace (main checkout, gitignored): `.superpowers/sdd/2026-09-29-live-testing-round-c2-front/` (`progress.md`, `task-N-report.md`, `final-fix-report.md`)
- One-screen spec: `docs/superpowers/specs/2026-09-28-one-screen-layout-design.md`
- `docs/specs/IDEAS.md`
