# Service Map

Which repo owns what, and what crosses between them. Ports and schemas: `ARCHITECTURE.md`.
Repo-local detail: `back/<svc>/.ai/AGENTS.md`.

| Service | Repo path | Owns | Emits | Consumes |
|---|---|---|---|---|
| ms-gateway | `back/ms-gateway` | routing, auth cookies, CSRF, BFF composition | — | — |
| ms-users | `back/ms-users` | users, sessions, preferences | `users.user.registered` | — |
| ms-finances | `back/ms-finances` | transactions, categories, budgets | `finances.transaction.created` | `banks.payment.recorded` |
| ms-banks | `back/ms-banks` | banks, accounts (CBU), cards, loans, installments | `banks.payment.recorded`, `banks.account.balance_adjusted`, `banks.account.low_balance`, `banks.card.expiring`, `banks.card.installment_due`, `banks.loan.reminder` | `finances.transaction.created` |
| ms-notifications | `back/ms-notifications` | notifications, SSE, email, category prefs | — | `users.user.registered`, `banks.account.balance_adjusted`, `banks.account.low_balance`, `banks.card.expiring`, `banks.card.installment_due`, `banks.loan.reminder`, `investments.threshold.breached` (fan-in) |
| ms-upload | `back/ms-upload` | file upload, MinIO, statement import runs | — | `ms-finances` create/delete transaction (REST) |
| ms-investments | `back/ms-investments` | holdings, quotes, derived investment view | `investments.threshold.breached` | `ms-finances` (REST), IOL broker API |
| front/financial-app | `front/financial-app` | Next.js app, all UI | — | REST via gateway |
| commons + BOM | `back/financial-app-parent` | `commons-{core,web,messaging}`, dependency versions | — | — |

Every row's event names are authoritative in that repo's `.ai/references/EVENTS.md`. If this
table and that file disagree, the repo file wins and this one is stale — fix it.
