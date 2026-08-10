# Scripts

An index, not a manual. Every script carries a usage block in its header — read that before
using anything below. All live in `scripts/`.

## `dev.sh` — local and Docker dev loop

The one you reach for daily. Two families of commands: run services **locally** with
Maven/npm against Dockerised infra, or run everything **in Docker**.

| Command | Does |
|---|---|
| `infra` | infrastructure only — postgres, kafka, minio |
| `local <service>` | infra + that one service locally with Maven |
| `front` | infra + the frontend locally with npm |
| `local-all [svc...] [--front]` | infra + several services in background; `stop-all`, `status-local`, `logs-local [svc]` manage them |
| `dev <service>` | infra + build + run one service in Docker |
| `up` / `prod` | all services in Docker, with / without microservice ports exposed |
| `down`, `restart [svc]`, `build [svc]`, `logs [svc]`, `status` | Docker lifecycle |

Local background runs write to `./logs/`.

## `git-manager.sh` — polyrepo git

Runs one git operation across the selected repos, since every service is its own repo.
Commands: `status`, `branch`, `checkout`, `commit`, `push`, `pull`, `log`, `diff`. No
argument opens an interactive menu.

Note `push` exists but `RULES.md` R11 still applies — never push on the user's behalf.

## `github/release-manager.sh` — promote and release

Interactive (fzf/gum). Subcommands:

- `status` — per repo, how far `develop` is ahead of `master` and the latest release tag
- `promote` — `develop` → `master` per repo: create or reuse the PR, wait for checks, merge
- `release` — dispatch the Release workflow with `major`/`minor`/`patch` → `vX.Y.Z` + images

Both run in parallel across repos **except the parent POM, which goes first and
synchronously** — every backend CI run checks out `parent@master` to resolve `commons-*`,
so services must never build against a stale parent. Needs `GITHUB_TOKEN`, fzf, gum, curl,
python3.

## `github/apply-rulesets.sh` — branch protection

Pushes `.github/rulesets/{master,develop}.json` to all nine repos. Takes `--dry-run`.
Needs a token with Administration: read/write.

## `github/read-ci-failures.sh` — triage

`WORKFLOW=ci.yml read-ci-failures.sh <service...|all>` — summarises the latest failing runs.
Service names are the short forms (`ms-banks`, `parent`, `front`).

## `github/fetch-failure-logs.sh` — raw logs

Downloads the latest failing run's logs to `/tmp/ci-logs/`. Needs `GITHUB_TOKEN`.

## `deploy.sh` — server bootstrap and update

Root repo only; images are prebuilt by CI and pulled from GHCR, so service sources are never
needed on the server. No argument runs the first-time `.env` wizard plus GHCR login;
`--update` pulls the root repo and images and restarts. Pin versions with `<SERVICE>_VERSION`
in `.env` — unset means `latest`, and rollback is setting the previous version and re-running
with `--update`.

## `backup.sh` — snapshots

Timestamped Postgres and MinIO archives into `./backups`.

## `ai-link.sh` / `ai-verify.sh` — AI context layer

`ai-link.sh` regenerates the symlinks from `.ai/` to the tool-specific entry points; run it
once after cloning, `--check` verifies without writing. `ai-verify.sh` runs the structural
gates over `.ai/`. See `ARCHITECTURE.md` § AI context layer.

## `dump-gateway-openapi.sh` — OpenAPI snapshot dump

Dumps `ms-gateway`'s `/v3/api-docs` to `front/financial-app/openapi/gateway.json` with sorted keys for BFF contract generation. Prerequisites: gateway service running (`docker compose --profile app up -d gateway`).

