# financial-app

Personal-finance platform for the Argentine market: Java 21 microservices behind a Spring
Cloud Gateway, a Next.js frontend, one PostgreSQL instance with per-service schemas, Kafka
for async domain events, MinIO for files.

**Polyrepo.** Every backend service and the frontend is its own standalone git repository,
gitignored by this parent repo — not submodules. Branch and commit per repo.

This file is the entry point for every AI tool working in this repo. Root `CLAUDE.md`,
`AGENTS.md` and `GEMINI.md` are generated symlinks to it (`scripts/ai-link.sh`).

## Always loaded

@.ai/references/RULES.md
@.ai/references/ARCHITECTURE.md
@.ai/references/WORKFLOW.md
@.ai/references/TECH_STACK.md

These four are resident in every session. Everything below loads on demand — read it when
its trigger fires, not before.

## Read when

| File | Read when |
|---|---|
| `.ai/references/APP_STRUCTURE.md` | before writing a controller, an exception, a repository, or anything touching auth |
| `.ai/references/PIPELINE.md` | before touching CI, rulesets, or cutting a release |
| `.ai/references/DEPLOYMENT.md` | before deploying, or changing compose, env vars or ports |
| `.ai/references/SCRIPTS.md` | before reaching for any script in `scripts/` |
| `.ai/references/REPORTS_STRUCTURE.md` | when writing a spec, a plan, or a development report |
| `.ai/references/GOALS_STRUCTURE.md` | when writing the goals section of a plan |

## Services

| Service | Port | Service | Port |
|---|---|---|---|
| ms-gateway | 8080 | ms-notifications | 8084 |
| ms-users | 8081 | ms-upload | 8085 |
| ms-finances | 8082 | ms-investments | 8086 |
| ms-banks | 8083 | front/financial-app | 3000 |

`back/financial-app-parent` is the Maven BOM plus `commons-{core,web,messaging}` — not a
runtime service.

> **Before reading or editing any file under `back/<service>/` or `front/`, first read
> `.ai/services/<service>.md`.** It carries repo-local facts nothing else duplicates.
> Those files arrive in sub-project P2; until then, read that repo's own `README.md`.

## Skills and agents

| Skill | Use for |
|---|---|
| `ddd` | designing, reviewing or refactoring any backend service — layers, dependency rule, ports and adapters |
| `solid` | class design: splitting a growing class, placing a new responsibility |

Both load automatically when their description matches the task; invoke by name to force it.
`.ai/agents/` is populated by sub-project P3.

## Mode

Classify the request as **Researching**, **Planning**, **Developing** or
**Debugging / Hotfix**, then follow that mode's numbered steps in `WORKFLOW.md`. Do not mix
modes in one pass.

## Non-negotiables

`R11` never `git push` · `R12` never add a `Co-Authored-By` trailer · `R13` never commit
unless asked · `R15` explain and ask before any destructive change.

Full text and the rest of the rules are in `RULES.md`, already loaded. Cite rules by id.

## Elsewhere

Human-readable material — rationale, onboarding, diagrams — lives in `docs/`; start at
`docs/GETTING-STARTED.md`. Known bugs, gaps and tech debt: `docs/specs/IDEAS.md`. Read it
before planning anything in an area you have not touched recently.
