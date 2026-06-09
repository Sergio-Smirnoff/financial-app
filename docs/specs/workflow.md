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

## CI/CD

Central reusable workflows live in this root repo (`.github/workflows/`); every service
repo holds thin callers referencing them `@master`.

| Reusable workflow | Used by | Does |
|---|---|---|
| `backend-ci.yml` | 7 backend services | parent install → `mvn verify` → docker build (no push) |
| `frontend-ci.yml` | frontend | `npm ci` → lint → build → docker build (no push) |
| `parent-ci.yml` | financial-app-parent | `mvn verify` on commons modules |
| `backend-publish.yml` / `frontend-publish.yml` | 8 repos | build + push GHCR: `latest`, `sha-*`, semver on release |
| `release.yml` | 8 repos | bump dropdown → next `vX.Y.Z` tag + GitHub Release → publish |

Triggers per service repo:
- `ci.yml`: every PR + push to develop/master → status check `ci / build`
- `docker-publish.yml`: push to master or `v*` tag
- `release.yml`: manual (Actions tab dropdown) or `scripts/github/release-manager.sh` (`release`)

Branch rulesets (applied via `scripts/github/apply-rulesets.sh`, JSON in `.github/rulesets/`):
- `master`: PR required, `ci / build` check required, no force-push/delete
- `develop`: no force-push/delete; direct push allowed (local merge flow preserved)

Copilot review: enabled account-wide ("Automatic Copilot code review" in
Settings → Copilot → Code review) — the ruleset API field is not available on this plan.

Release flow: merge develop→master via PR → trigger Release with bump type
(major/minor/patch) → image published as `X.Y.Z` + `X.Y` + `latest` + `sha-*`.
The caller `release.yml` only runs from `master` (`if: github.ref == 'refs/heads/master'`).

Promotion: `scripts/github/release-manager.sh` (`promote`) creates the develop→master PR,
waits for `ci / build`, and merges — one command instead of per-repo UI clicking
(`parent` and `front` are valid service names alongside the `ms-*` ones).

Failure triage: `scripts/github/fetch-failure-logs.sh` downloads the latest failing run
logs to `/tmp/ci-logs/` (needs `GITHUB_TOKEN`).

All four scripts read `GITHUB_TOKEN` from the environment (export per session — never in
`.env`). Fine-grained PAT scoped to the 9 repos, with:

| Permission | Needed by |
|---|---|
| Administration: Read and write | `apply-rulesets.sh` |
| Actions: Read and write | `release-manager.sh` (`release`), `fetch-failure-logs.sh`, `read-ci-failures.sh` |
| Pull requests: Read and write | `release-manager.sh` (`promote` — create PR) |
| Contents: Read and write | `release-manager.sh` (`promote` — merge) |

Spec: `docs/superpowers/specs/2026-06-05-github-actions-ci-pipeline-design.md`

---

[Master](00-master.md) | [Rules](rules.md) | [Architecture](architecture.md)
