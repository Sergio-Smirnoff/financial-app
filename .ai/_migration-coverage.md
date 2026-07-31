# Migration coverage matrix — P1

Generated mechanically from `/usr/bin/grep -nE '^#{1,3} '` over the six source files, not
transcribed by hand. Every row must reach `Verified: yes` before Task 11 deletes anything.

`Destination` values come from the spec's §6 content mapping table. A row whose destination is
`DROPPED (P2)` is a deliberate omission recorded in spec §13, not a gap.

| Source | Lines | Heading | Destination | Verified |
|---|---|---|---|---|
| `CLAUDE.md` | 1-14 | # CLAUDE.md — financial-app (parent / root) | AGENTS.md (identity + polyrepo one-liner) | no |
| `CLAUDE.md` | 15-33 | ## 0. Read-before-plan (mandatory, in order) | WORKFLOW.md, folded into the four modes | no |
| `CLAUDE.md` | 34-54 | ## 1. Does this file work for other AI tools? | ARCHITECTURE.md § AI context layer | no |
| `CLAUDE.md` | 55-86 | ## 2. System map | ARCHITECTURE.md | no |
| `CLAUDE.md` | 87-122 | ## 3. Domain model catalog (bird's-eye — see each service spec for full ER diagrams) | DROPPED (P2) | no |
| `CLAUDE.md` | 123-174 | ## 4. DDD layering (every backend service, identical shape) | split: layering prose → `.ai/skills/ddd/SKILL.md`; package tree → `.ai/references/APP_STRUCTURE.md` | yes |
| `CLAUDE.md` | 175-207 | ## 5. Naming conventions | RULES.md R7 | yes |
| `CLAUDE.md` | 208-221 | ## 6. Response envelope (every endpoint, every service) | APP_STRUCTURE.md | yes |
| `CLAUDE.md` | 222-236 | ## 7. Comment policy | RULES.md R9 | yes |
| `CLAUDE.md` | 237-255 | ## 8. Git / workflow rules (apply everywhere, every repo) | RULES.md R11–R14 + WORKFLOW.md + PIPELINE.md | no |
| `CLAUDE.md` | 256-263 | ## 9. Approval before destructive changes | RULES.md R15 | yes |
| `CLAUDE.md` | 264-268 | ## Footer | DROPPED (navigation only) | no |
| `docs/specs/rules.md` | 1-6 | # Implementation Rules | RULES.md (header) | no |
| `docs/specs/rules.md` | 7-23 | ## 1. DDD Always | skills/ddd | yes |
| `docs/specs/rules.md` | 24-44 | ## 2. SOLID & OOP Principles | skills/solid | yes |
| `docs/specs/rules.md` | 45-50 | ## 3. ApiResponse\<T\> Envelope | APP_STRUCTURE.md | yes |
| `docs/specs/rules.md` | 51-60 | ### 3.1 Fields | APP_STRUCTURE.md | yes |
| `docs/specs/rules.md` | 61-71 | ### 3.2 Success example | APP_STRUCTURE.md | yes |
| `docs/specs/rules.md` | 72-93 | ### 3.3 Error examples | APP_STRUCTURE.md | yes |
| `docs/specs/rules.md` | 94-110 | ### 3.4 Controller usage | APP_STRUCTURE.md | yes |
| `docs/specs/rules.md` | 111-112 | ## 4. Exception Handling | APP_STRUCTURE.md | yes |
| `docs/specs/rules.md` | 113-123 | ### 4.1 GlobalExceptionHandler | APP_STRUCTURE.md | yes |
| `docs/specs/rules.md` | 124-138 | ### 4.2 Exception hierarchy | APP_STRUCTURE.md | yes |
| `docs/specs/rules.md` | 139-162 | ### 4.3 DomainError → HTTP status mapping | APP_STRUCTURE.md | yes |
| `docs/specs/rules.md` | 163-176 | ### 4.4 Exception selection guide | APP_STRUCTURE.md | yes |
| `docs/specs/rules.md` | 177-182 | ### 4.5 Catch order | APP_STRUCTURE.md | yes |
| `docs/specs/rules.md` | 183-194 | ## 5. Configuration | APP_STRUCTURE.md | yes |
| `docs/specs/rules.md` | 195-206 | ## 6. Persistence | APP_STRUCTURE.md | yes |
| `docs/specs/rules.md` | 207-220 | ## 7. Code Comments | RULES.md R9 | yes |
| `docs/specs/rules.md` | 221-233 | ## 8. Supported Currencies | APP_STRUCTURE.md | yes |
| `docs/specs/rules.md` | 234-240 | ### Currency type rules | APP_STRUCTURE.md | yes |
| `docs/specs/rules.md` | 241-252 | ### Config source | APP_STRUCTURE.md | yes |
| `docs/specs/rules.md` | 253-269 | ## 9. CI / CD Constraints | split: the two hard bans → `RULES.md` R16–R17; remainder → `PIPELINE.md` | no |
| `docs/specs/rules.md` | 270-272 | ## Footer | DROPPED (navigation only) | no |
| `docs/specs/workflow.md` | 1-2 | # Development Workflow | WORKFLOW.md (header) | no |
| `docs/specs/workflow.md` | 3-6 | ## Branching Strategy | WORKFLOW.md + RULES.md | no |
| `docs/specs/workflow.md` | 7-14 | ### Branch model | WORKFLOW.md + RULES.md | no |
| `docs/specs/workflow.md` | 15-34 | ### Flow | WORKFLOW.md + RULES.md | no |
| `docs/specs/workflow.md` | 35-43 | ## Commit Rules | `RULES.md` R14 | yes |
| `docs/specs/workflow.md` | 44-58 | ## Read-Before-Plan | WORKFLOW.md, folded into the four modes | no |
| `docs/specs/workflow.md` | 59-71 | ## Update-Docs-After-Implementation | RULES.md R18 | no |
| `docs/specs/workflow.md` | 72-84 | ## Per-Repo Commit Targets | WORKFLOW.md + RULES.md | no |
| `docs/specs/workflow.md` | 85-135 | ## CI/CD | PIPELINE.md | no |
| `docs/specs/architecture.md` | 1-6 | # Architecture | ARCHITECTURE.md (header) | no |
| `docs/specs/architecture.md` | 7-51 | ## 1. Polyrepo topology | ARCHITECTURE.md | no |
| `docs/specs/architecture.md` | 52-82 | ## 2. Runtime topology | ARCHITECTURE.md | no |
| `docs/specs/architecture.md` | 83-122 | ## 3. Auth / cookie / CSRF flow | APP_STRUCTURE.md | yes |
| `docs/specs/architecture.md` | 123-141 | ## 4. Data stores | ARCHITECTURE.md | no |
| `docs/specs/architecture.md` | 142-163 | ## 5. DDD layering | skills/ddd | yes |
| `docs/specs/architecture.md` | 164-182 | ## 6. CI/CD | PIPELINE.md | no |
| `docs/specs/deployment.md` | 1-2 | # Deployment & Dev-Ops | DEPLOYMENT.md (header) | no |
| `docs/specs/deployment.md` | 3-29 | ## 1. scripts/dev.sh Command Reference | SCRIPTS.md | no |
| `docs/specs/deployment.md` | 30-47 | ## 2. Port Map | DEPLOYMENT.md | no |
| `docs/specs/deployment.md` | 48-63 | ### Swagger URLs | DEPLOYMENT.md | no |
| `docs/specs/deployment.md` | 64-95 | ## 3. Environment Variables | DEPLOYMENT.md | no |
| `docs/specs/deployment.md` | 96-118 | ## 4. Startup Flow | DEPLOYMENT.md | no |
| `docs/specs/deployment.md` | 119-120 | ## 5. Docker vs Local Dev | DEPLOYMENT.md | no |
| `docs/specs/deployment.md` | 121-130 | ### docker-compose.override.yml | DEPLOYMENT.md | no |
| `docs/specs/deployment.md` | 131-142 | ### Production mode | DEPLOYMENT.md | no |
| `docs/specs/deployment.md` | 143-154 | ### Local (hybrid) mode | DEPLOYMENT.md | no |
| `docs/specs/deployment.md` | 155-189 | ## 6. GHCR Image Tags and Releases | DEPLOYMENT.md | no |
| `docs/specs/deployment.md` | 190-196 | ## 7. Deploy on any server | DEPLOYMENT.md | no |
| `docs/specs/deployment.md` | 197-205 | ### 7.1 Requirements | DEPLOYMENT.md | no |
| `docs/specs/deployment.md` | 206-246 | ### 7.2 First-time deploy | DEPLOYMENT.md | no |
| `docs/specs/deployment.md` | 247-258 | ### 7.3 What is reachable after deploy | DEPLOYMENT.md | no |
| `docs/specs/deployment.md` | 259-271 | ### 7.4 Update / rollback | DEPLOYMENT.md | no |
| `docs/specs/deployment.md` | 272-285 | ### 7.5 Operations | DEPLOYMENT.md | no |
| `docs/specs/deployment.md` | 286-300 | ### 7.6 Troubleshooting | DEPLOYMENT.md | no |
| `docs/specs/00-master.md` | 1-12 | # financial-app — Master Spec (Hub) | AGENTS.md (reference index replaces the hub) | no |
| `docs/specs/00-master.md` | 13-36 | ## Spec map | AGENTS.md — the reference index replaces the hub | no |
| `docs/specs/00-master.md` | 37-46 | ## Cross-cutting specs | AGENTS.md (reference index) | no |
| `docs/specs/00-master.md` | 47-62 | ## Service specs | AGENTS.md (reference index) | no |
| `docs/specs/00-master.md` | 63-71 | ## How to use these docs | AGENTS.md (reference index) | no |
