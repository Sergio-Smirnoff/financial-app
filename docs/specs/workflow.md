# Development Workflow

## Branching Strategy

This is a **polyrepo** project: every backend service (`back/<service>/`) and the frontend (`front/financial-app/`) is its own independent git repository, gitignored by the parent. The parent `financial-app/` directory is also a git repo that owns central docs and infrastructure. Branching must be performed **independently in each affected repo**.

### Branch model

| Branch | Role |
|---|---|
| `master` | Production. Protected. Never commit feature work directly here. |
| `develop` | Integration branch. Feature branches merge here when finished. |
| `<change-name>` | Short-lived feature branch, named after the change (e.g. `feat/ms-banks-ddd`, `fix/gateway-rate-limit`). Always branched from `master`. |

### Flow

```mermaid
gitGraph
   commit id: "existing master"
   branch develop
   checkout develop
   commit id: "prior integration"
   checkout master
   branch feat/change-name
   commit id: "implement change"
   commit id: "tests + docs update"
   checkout develop
   merge feat/change-name id: "merge to develop"
```

> **Replicated per repo.** If a change touches ms-finances and the frontend, create a `feat/change-name` branch in `back/ms-finances/` *and* in `front/financial-app/` separately. Merge each branch into that repo's own `develop` when done.

---

## Commit Rules

> [!CAUTION]
> - **Never run `git push`** — the user controls all remote pushes. Only stage and commit locally.
> - **Never add a `Co-Authored-By` trailer** to any commit message.
> - **Do NOT commit unless the user explicitly asks.** Prepare changes (edit files, run tests) and wait for the instruction.

---

## Read-Before-Plan

Before writing any plan or making any change, read the following in order:

1. The affected repo's own `README.md` (always present in every service repo and the parent repo).
2. When working inside the parent workspace or when cross-cutting concerns are involved:
   - `docs/specs/00-master.md` — system-wide overview and spec map.
   - `docs/specs/services/<service>.md` — the spec for the specific service being changed.
   - `docs/specs/rules.md` — coding standards, DDD conventions, naming rules.
   - `docs/specs/workflow.md` — this file.

Never start planning or implementing without completing this read step.

---

## Update-Docs-After-Implementation

After every implementation (feature, fix, refactor), update **both**:

| Document | What to update |
|---|---|
| `docs/specs/services/<service>.md` | Domain model changes, new endpoints, architectural decisions, Flyway migration notes. |
| `<service-repo>/README.md` | Any change to how the service is built, run, configured, or tested; updated port/env-var reference. |

The duplication is intentional: `README.md` is the quick-start for anyone who only clones that service; `docs/specs/services/<x>.md` is the authoritative design record for the whole system. Both must stay in sync.

---

## Per-Repo Commit Targets

| Files changed | Commit goes into |
|---|---|
| Files under `back/<service>/` | `back/<service>/` repo (that service's own git repo) |
| Files under `front/financial-app/` | `front/financial-app/` repo |
| `docs/`, `infra/`, `docker-compose*.yml`, `scripts/`, `.env.example`, root `README.md` | Parent `financial-app/` repo |
| `docs/specs/*.md`, `docs/specs/services/*.md` | Parent `financial-app/` repo |

When a single logical change touches multiple repos, create one commit per repo. Write commit messages that cross-reference each other if helpful (e.g. `see ms-finances commit abc1234`), but keep each repo's history self-contained.

---

[Master](00-master.md) | [Rules](rules.md) | [Architecture](architecture.md)
