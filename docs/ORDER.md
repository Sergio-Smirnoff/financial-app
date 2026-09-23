# Build order — financial-app's part in the homelab automations / finance platform work

The owner's homelab repository (private) holds the cross-repo build order (`docs/ORDER.md`) and
the specs. This file is the public-safe slice that applies to work in the financial-app repos.
If it disagrees with the private order file, that file wins — update this one.

## Principle

The finance platform (a separate pipeline and MCP server) **does not change financial-app
code**: it reads and writes through the existing API as the user. The **only** planned code
change is the homelab "21b" catch-up PR below.

## Step A1 — 21b catch-up endpoints (can start now, in parallel with the homelab work)

| Service repo | Endpoint | Behaviour |
|---|---|---|
| `financial-app-back-ms-investments` | `POST /api/v1/investments/portfolio/snapshot/ensure-today` | for the JWT's user only: today's (ART) snapshot exists → `{created: false, date}`; else capture that user's snapshot → `{created: true, date}`. The midnight all-user scheduler skips users that already have today's row instead of throwing on `UNIQUE(user_id, snapshot_date)` |
| `financial-app-back-ms-notifications` | `POST /api/v1/notifications/monthly-summary/ensure` | for the JWT's user, the **previous** month: new table `monthly_summary_sent(user_id, month)` with a unique key; row exists → `{sent: false, month}`; opted out → `{sent: false, reason: "opted-out"}`; else send (email + push), insert, `{sent: true, month}`. The 1st-of-month scheduler uses the same record |

Tests per endpoint: a second call is a no-op; another user's data and sends are untouched;
401 without a JWT; the scheduler path honours the same record.

**Order:** the PR is merged **and deployed** before the homelab router and workflows that call
these endpoints are built. Restarting the deployed stack needs the owner's go.

## Verify before starting

1. Work in the standalone service repos (this parent repo tracks orchestration only), on a
   branch off `develop`, merged by PR.
2. The base you start from equals the version deployed on the server (`1.3.0` on 2026-09-23).
3. Take the next free Flyway version in each service.
4. The facts callers rely on (read in source 2026-09-23 — ms-users `917cb51` and the gateway's
   `JwtAuthFilter`) still hold; if a change here breaks one, the homelab order file must be
   updated first:
   - the gateway authenticates with the `access_token` **cookie** only;
   - each login creates its own session row and revokes no other session;
   - refresh rotates the refresh token and fails after the user's inactivity policy
     (default 30 min);
   - `POST /api/v1/auth/logout` revokes the calling session;
   - a password change revokes all of the user's sessions.
5. Automated callers log in at the start of each run and log out at the end.

## Later (no code change)

- Finance platform S9: an MCP server and the pipeline read holdings and record fills through
  the existing endpoints (a separate write token and an explicit confirmation on the caller's
  side). The broker account maps onto the existing model via the CBU the user wires from,
  with the broker name in the description.
- S14 (much later): OAuth for claude.ai clients, tied to this repo's MCP hardening program.
