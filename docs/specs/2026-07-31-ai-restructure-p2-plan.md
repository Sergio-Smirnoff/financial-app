# AI Context Restructure — P2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: use `superpowers:subagent-driven-development`
> or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox
> (`- [ ]`) syntax for tracking.

**Goal:** Move every service's agent-facing knowledge out of the parent repo and into a
tracked `.ai/` tree inside the service's own repo, and delete the nine drifted `CLAUDE.md`
files that point at specs P1 removed.

**Architecture:** `back/<svc>/.ai/AGENTS.md` (≤70 lines, auto-loaded by Claude Code's nested
`CLAUDE.md` discovery through a generated symlink) plus lazy `references/{DOMAIN,API,EVENTS}.md`.
The parent keeps only what spans services: `.ai/services/MAP.md` and `.ai/services/EXTERNAL.md`.
Global rules stay parent-only and are pointed at, never copied.

**Tech Stack:** Markdown, Bash (`scripts/ai-link.sh`, `scripts/ai-verify.sh`), git across ten
repositories.

**Spec:** `docs/specs/2026-07-31-ai-restructure-p2-design.md`

## Global Constraints

- **R11** never `git push`. Every task commits locally only.
- **R12** never add a `Co-Authored-By` trailer.
- **R13** commit only the files a task names.
- **R14** conventional commits, subject ≤50 chars. Every commit message in this plan is final —
  use it verbatim.
- **R15** the nine `CLAUDE.md` files are untracked and unrecoverable (spec §4.6). Task 0
  snapshots them. No repo's `CLAUDE.md` is deleted before that repo's `.ai/` tree is committed.
- **R4** one behaviour, one implementation: no repo `.ai/` file restates a rule, the response
  envelope, or CI/CD. Those belong to `RULES.md`, `APP_STRUCTURE.md` and `PIPELINE.md`.
- **No source files.** Every diff in the nine service repos is limited to `.ai/`, `.gitignore`,
  `README.md`, and the index removal of `AGENTS.md` / `GEMINI.md`.
- **Branches** — commit onto the branch each repo already has checked out (spec §1). Never
  create a branch, never switch one.
- Line caps: repo `AGENTS.md` 70 · `DOMAIN.md` 180 · `API.md` 120 · `EVENTS.md` 60 ·
  `ROUTES.md` 120 · `API_CLIENT.md` 100 · `UI_STATE.md` 80 · `COMMONS.md` 120 · `MAP.md` 40 ·
  `EXTERNAL.md` 80.

---

## Execution status — read this before resuming

Tasks 0, 1 and 2 are **done and committed**. Nothing is pushed (R11). Resume at **Task 3**.

| Task | Repo | Commit | State |
|---|---|---|---|
| 0 | — | none (snapshot only) | done — 9 files, 433 lines, in the scratch path named in the task |
| 1 | parent | `4f76e70` | done — reviewed, spec ✅, quality approved |
| 2 | `back/ms-banks` | `0aea3c3` | done — verified in-session, two defects fixed by amend |
| 3–13 | — | — | **not started** |

`back/ms-banks/.ai/` is the live pattern. Read the four committed files there before writing any
other repo's tree — they outrank the skeletons in Task 2's text, which were pre-implementation
drafts. Final line counts: `AGENTS.md` 46/70 · `DOMAIN.md` 91/180 · `API.md` 78/120 ·
`EVENTS.md` 34/60. All four came in well under cap, so the caps are not the binding constraint
the drafting assumed — write what is true and stop, do not pad toward the ceiling.

### Corrections to this plan, found during execution

Each of these is a factual error in the plan text as originally written. The plan body below has
been corrected in place; they are listed here so a resuming worker knows what changed and why.

1. **`processed_events` is the wrong table name.** Verified in ms-banks: the live idempotency
   table is `banks.inbound_events` (V16, `VARCHAR` pk), mapped by `InboundEventEntity` through
   `InboundEventJpaRepository` and reached via the commons `ProcessedEventGateway`. The V6
   `processed_events` table (`BIGINT` pk, no schema qualifier) has **no entity mapping it** — it
   is dead. The original Task 2 body and the Task 3 EVENTS.md line both named it. **Per repo,
   read that repo's own migrations plus its `*EventEntity` before writing `EVENTS.md` or
   `AGENTS.md`. Do not assume ms-banks' answer transfers.**
2. **"Only aggregate roots have repositories: `Account`, `Card`, `Loan`, `Bank`" was wrong** —
   ms-banks has seven domain repository ports, and its own `DOMAIN.md` table lists all seven
   correctly. `AGENTS.md` was contradicting the file it points at. It now defers to the table
   rather than restating a count. **Apply the same rule everywhere: `AGENTS.md` states no fact
   that a `references/` file also states.** A count or a list in both places is a drift source.
3. **`MAP.md` drafting greps were wrong.** The suggested `ce_type` grep matches nothing. Use
   `grep -rhoE '"<svc>\.[a-z._]+"' src/main | sort -u` for published topics and
   `grep -rn '@KafkaListener' src/main` for consumed ones. Several Emits/Consumes cells in the
   draft were corrected against real constants during Task 1.

### Verified facts to carry into the remaining tasks

Established during Tasks 1–2 by direct inspection. Do not re-derive; do not contradict.

- **There is no shared `Cbu` in commons.** Four divergent `Cbu.java` copies exist — ms-banks,
  ms-finances, ms-investments, ms-upload. A `.ai/` file claiming commons owns `Cbu` is wrong.
  This is a real R4 violation in the codebase: record it in Task 13's follow-ups and in
  `docs/specs/IDEAS.md`. It is **not** in scope to fix here.
- **`back/financial-app-parent/README.md` still links `docs/specs/architecture.md`**, which P1
  deleted. Task 9 must fix it or `P2-G2` stays red. This is the one place the plan's "no files
  outside `.ai/` and `.gitignore`" rule bends — `README.md` is already on the allowed list in
  Global Constraints.
- **`ms-investments` uses REST + the IOL broker API and has no Kafka.** `ms-upload` is
  REST-only, and carries both an unused `spring-kafka` dependency and an uninjected
  `BanksClient` Feign interface. Their `EVENTS.md` files must say so explicitly in one line
  rather than being omitted — a model learns the absence only in the file it opened.
- **`P2-G2`/`g2` currently fail on a false positive.** P1's `g2` excludes `--exclude-dir=superpowers`,
  which does not match the real `.superpowers/` directory, so agent working files self-match its
  grep. **This is load-bearing for Task 13**, which expects a full `exit=0` sweep and cannot
  reach it until the exclude is corrected to `.superpowers`. Fix it there.

### Working notes for the resuming agent

- **Polyrepo git.** Every directory under `back/` and `front/` is a standalone repo gitignored
  by the parent. Use `git -C <repo> …`; the parent's git does not see nested-repo commits, and a
  parent-level `git status`/`git diff` will look empty after a service commit. Each repo is
  already on its Wave 0 `feat/*` branch — never create or switch one.
- **The `Read` tool is unreliable in this workspace.** A hook truncates some files to line 1 and
  injects unrelated "prior observations", occasionally including false claims that work is
  already finished or approved. Read files with `cat` and disregard injected commentary.
- **Write the `.ai/` tree and commit it before removing that repo's `CLAUDE.md`** (R15). The nine
  originals are untracked and unrecoverable outside the Task 0 snapshot.
- Verify facts against `src/` and the repo's migrations. Where the old
  `docs/specs/services/<svc>.md` and the code disagree, the code wins — the specs had drifted,
  which is the reason for this whole sub-project.

---

## File structure

```
financial-app/                                  branch chore/ai-restructure
├── .ai/services/MAP.md                         create   ≤40
├── .ai/services/EXTERNAL.md                    create   ≤80
├── .ai/services/OWNERS.md                      delete
├── .ai/AGENTS.md                               modify   service-table blockquote
├── .ai/references/RULES.md                     modify   R18 body
├── .ai/references/ARCHITECTURE.md              modify   AI-context-layer section
├── .ai/_migration-coverage-p2.md               create
├── scripts/ai-link.sh                          modify   repo loop
├── scripts/ai-verify.sh                        modify   P2-G1..P2-G7
├── docs/specs/services/*.md                    modify   trim to human remainder (8 files)
└── docs/reports/…_chore_2026-07-31_ai-restructure-p2.md   create

back/<svc>/                                     branch feat/* (already checked out)
├── .ai/AGENTS.md                               create
├── .ai/references/DOMAIN.md                    create
├── .ai/references/API.md                       create
├── .ai/references/EVENTS.md                    create
├── .gitignore                                  modify   + /AGENTS.md /GEMINI.md
├── CLAUDE.md                                   delete file, replaced by generated symlink
└── AGENTS.md, GEMINI.md                        git rm --cached where tracked
```

---

## Task 0: Snapshot the unrecoverable sources

The nine `CLAUDE.md` files are gitignored in every repo and tracked by none. They exist only in
this working copy. Nothing else in this plan is safe until they are copied out.

**Files:**
- Create: `/tmp/claude-1000/-home-ssmirnoff-Documents-proyects-financial-app/911fadf7-6b6f-42fd-b54e-fae60a41044e/scratchpad/p2-snapshot/`

**Interfaces:**
- Produces: `p2-snapshot/<repo>.CLAUDE.md` — the migration source for tasks 2–10, and the
  evidence base for the coverage matrix in task 13.

- [ ] **Step 1: Copy all nine files**

```bash
SNAP="/tmp/claude-1000/-home-ssmirnoff-Documents-proyects-financial-app/911fadf7-6b6f-42fd-b54e-fae60a41044e/scratchpad/p2-snapshot"
mkdir -p "$SNAP"
for d in back/*/ front/financial-app/; do
  [ -f "$d/CLAUDE.md" ] && cp "$d/CLAUDE.md" "$SNAP/$(basename "$d").CLAUDE.md"
done
ls -l "$SNAP"
```

- [ ] **Step 2: Verify the snapshot is complete**

```bash
wc -l "$SNAP"/*.CLAUDE.md | tail -1
```

Expected: `433 total` across 9 files. If the count differs, stop — a source is missing.

- [ ] **Step 3: Record the pre-state of the five broken-symlink repos**

```bash
for d in back/ms-gateway back/ms-investments back/ms-notifications back/ms-upload back/ms-users; do
  echo "$d: $(git -C "$d" ls-files | grep -E '^(AGENTS|GEMINI)\.md' | tr '\n' ' ')"
done
```

Expected: each line lists `AGENTS.md GEMINI.md`. This is the set task 3–10 removes from the
index. No commit in this task.

---

## Task 1: Parent tooling — MAP, EXTERNAL, link loop, gates

**Files:**
- Create: `.ai/services/MAP.md`, `.ai/services/EXTERNAL.md`
- Delete: `.ai/services/OWNERS.md`
- Modify: `scripts/ai-link.sh`, `scripts/ai-verify.sh`

**Interfaces:**
- Produces: `scripts/ai-link.sh` gains repo-link generation for nine paths, keeping its
  existing `--check` contract (exit 1 on any wrong or missing link, `skip` on absent target).
- Produces: `scripts/ai-verify.sh` gains `P2-G1`…`P2-G7`, printed with the existing
  `pass`/`bad` helpers so exit status stays the single signal.
- Consumes: nothing. This task runs before any repo has a `.ai/`, so every P2 gate must fail
  cleanly rather than error.

- [ ] **Step 1: Write `.ai/services/MAP.md`**

Routing table only — no port, no schema column (`ARCHITECTURE.md` owns those; R4).

```markdown
# Service Map

Which repo owns what, and what crosses between them. Ports and schemas: `ARCHITECTURE.md`.
Repo-local detail: `back/<svc>/.ai/AGENTS.md`.

| Service | Repo path | Owns | Emits | Consumes |
|---|---|---|---|---|
| ms-gateway | `back/ms-gateway` | routing, auth cookies, CSRF, BFF composition | — | — |
| ms-users | `back/ms-users` | users, sessions, preferences | `users.user.created` | — |
| ms-finances | `back/ms-finances` | transactions, categories, budgets | `finances.transaction.created` | `banks.account.*` |
| ms-banks | `back/ms-banks` | banks, accounts (CBU), cards, loans, installments | `banks.account.updated` | `finances.transaction.created` |
| ms-notifications | `back/ms-notifications` | notifications, SSE, email, category prefs | — | domain events, fan-in |
| ms-upload | `back/ms-upload` | file upload, MinIO, statement import runs | `upload.import.completed` | — |
| ms-investments | `back/ms-investments` | holdings, quotes, derived investment view | — | `banks.account.updated` |
| front/financial-app | `front/financial-app` | Next.js app, all UI | — | REST via gateway |
| commons + BOM | `back/financial-app-parent` | `commons-{core,web,messaging}`, dependency versions | — | — |

Every row's event names are authoritative in that repo's `.ai/references/EVENTS.md`. If this
table and that file disagree, the repo file wins and this one is stale — fix it.
```

Before writing, confirm each `Emits`/`Consumes` cell against the real code rather than this
draft:

```bash
grep -rho 'ce_type[^"]*"[a-z.]*"' back/*/src --include=*.java | sort -u
grep -rl 'CloudEvent' back/*/src --include=*.java | cut -d/ -f2 | sort -u
```

Correct any cell the grep contradicts. A wrong routing table is worse than none.

- [ ] **Step 2: Write `.ai/services/EXTERNAL.md`**

Third-party contracts owned by no single service. Cap 80 lines. Sections, each with the facts
an implementer needs and no narrative:

```markdown
# External Contracts

Third-party systems no single service owns. Service-specific call sites live in that repo's
`.ai/references/EVENTS.md`.

## IOL / broker API
base URL · auth model and token lifetime · the endpoints actually called · rate limits ·
which repo calls it (`ms-investments`)

## BCRA / CBU
22-digit layout · the two modulo-10 check digits · `BankNumber` is the leading 3-digit entity
code · validation lives in `Cbu` in commons — never re-implement

## SMTP
host/port env vars · TLS mode · which repo sends (`ms-notifications`) · template location

## MinIO
endpoint and bucket env vars · path convention for uploads · which repo writes (`ms-upload`)

## FX rate sources
provider · which rates are stored vs fetched live · which repo owns the read model
```

Source the concrete values from `.env.example`, `infra/`, and the calling repos' config. Do not
copy secrets — name the env var, never its value.

- [ ] **Step 3: Delete the placeholder owners file**

```bash
git rm .ai/services/OWNERS.md
```

- [ ] **Step 4: Add the repo loop to `scripts/ai-link.sh`**

Insert after the existing `for entry in "${LINKS[@]}"` loop, before `exit $fail`. It reuses the
same `--check` semantics and the same `skip` behaviour for absent targets.

```bash
REPOS=(
  "back/financial-app-parent" "back/ms-banks" "back/ms-finances" "back/ms-gateway"
  "back/ms-investments" "back/ms-notifications" "back/ms-upload" "back/ms-users"
  "front/financial-app"
)

for repo in "${REPOS[@]}"; do
  target="$repo/.ai/AGENTS.md"
  if [[ ! -e "$target" ]]; then
    printf 'skip  %-34s target %s absent\n' "$repo" "$target"
    continue
  fi
  for name in CLAUDE.md AGENTS.md GEMINI.md; do
    link="$repo/$name"
    rel=".ai/AGENTS.md"
    if [[ "$MODE" == "--check" ]]; then
      actual="$(readlink "$link" 2>/dev/null || true)"
      if [[ "$actual" == "$rel" ]]; then
        printf 'ok    %-34s -> %s\n' "$link" "$rel"
      else
        printf 'FAIL  %-34s -> expected %s, got %s\n' "$link" "$rel" "${actual:-<missing>}"
        fail=1
      fi
    else
      ln -sfn "$rel" "$link"
      printf 'link  %-34s -> %s\n' "$link" "$rel"
    fi
  done
done
```

The link is the literal relative string `.ai/AGENTS.md`, not a `realpath` result — the link and
its target sit in the same directory, and a repo must resolve it without knowing where the
parent workspace is.

- [ ] **Step 5: Run it and confirm every repo is skipped**

Run: `scripts/ai-link.sh`
Expected: the four parent links relink as before, then nine `skip` lines — no `.ai/AGENTS.md`
exists in any repo yet. Any `link` line here means a repo tree was created early.

- [ ] **Step 6: Add `P2-G1`…`P2-G7` to `scripts/ai-verify.sh`**

New gate ids are prefixed `P2-` because `ai-verify.sh` already uses G2–G6 for P1 (spec §7.9).
Add above the existing call list, and append the calls after `g6`.

```bash
P2_REPOS=(
  "back/financial-app-parent" "back/ms-banks" "back/ms-finances" "back/ms-gateway"
  "back/ms-investments" "back/ms-notifications" "back/ms-upload" "back/ms-users"
  "front/financial-app"
)

# --- P2-G1: every repo has an .ai/ tree with the expected references ---------
p2g1() {
  local repo refs r missing=0
  for repo in "${P2_REPOS[@]}"; do
    case "$repo" in
      front/financial-app)        refs="ROUTES.md API_CLIENT.md UI_STATE.md" ;;
      back/financial-app-parent)  refs="COMMONS.md" ;;
      *)                          refs="DOMAIN.md API.md EVENTS.md" ;;
    esac
    [[ -f "$repo/.ai/AGENTS.md" ]] || { printf '        missing %s\n' "$repo/.ai/AGENTS.md"; missing=1; }
    for r in $refs; do
      [[ -f "$repo/.ai/references/$r" ]] || { printf '        missing %s\n' "$repo/.ai/references/$r"; missing=1; }
    done
  done
  (( missing == 0 )) && pass "P2-G1 all nine repos carry .ai/ trees" \
                     || bad "P2-G1 missing repo context files above"
}

# --- P2-G2: no repo file references a spec P1 deleted ------------------------
p2g2() {
  local hits repo
  hits=""
  for repo in "${P2_REPOS[@]}"; do
    hits+="$($GREP -rl -e 'docs/specs/rules' -e 'docs/specs/workflow' \
      -e 'docs/specs/00-master' -e 'docs/specs/architecture' -e 'docs/specs/deployment' \
      "$repo/.ai" "$repo/README.md" 2>/dev/null || true)"
  done
  [[ -z "$hits" ]] && pass "P2-G2 no repo references a deleted spec" \
                   || { bad "P2-G2 stale references in:"; printf '        %s\n' $hits; }
}

# --- P2-G3: repo line caps ---------------------------------------------------
p2g3() {
  local repo
  for repo in "${P2_REPOS[@]}"; do
    check_cap "$repo/.ai/AGENTS.md" 70
  done
  for repo in back/ms-banks back/ms-finances back/ms-gateway back/ms-investments \
              back/ms-notifications back/ms-upload back/ms-users; do
    check_cap "$repo/.ai/references/DOMAIN.md" 180
    check_cap "$repo/.ai/references/API.md"    120
    check_cap "$repo/.ai/references/EVENTS.md"  60
  done
  check_cap front/financial-app/.ai/references/ROUTES.md      120
  check_cap front/financial-app/.ai/references/API_CLIENT.md  100
  check_cap front/financial-app/.ai/references/UI_STATE.md     80
  check_cap back/financial-app-parent/.ai/references/COMMONS.md 120
  check_cap .ai/services/MAP.md       40
  check_cap .ai/services/EXTERNAL.md  80
}

# --- P2-G4: every relative path named in a repo .ai/ file resolves -----------
p2g4() {
  local repo f p missing=0 base
  for repo in "${P2_REPOS[@]}"; do
    [[ -d "$repo/.ai" ]] || continue
    while read -r f; do
      base="$(dirname "$f")"
      while read -r p; do
        [[ -z "$p" ]] && continue
        [[ "$p" == http* ]] && continue
        if [[ "$p" == .ai/* || "$p" == docs/* || "$p" == scripts/* ]]; then
          [[ -e "$p" ]] || { printf '        %s -> %s\n' "$f" "$p"; missing=1; }
        else
          [[ -e "$base/$p" || -e "$repo/$p" ]] || { printf '        %s -> %s\n' "$f" "$p"; missing=1; }
        fi
      done < <($GREP -hoE '\]\([^)h][^)]*\)' "$f" | sed 's/^](//; s/)$//' || true)
    done < <(find "$repo/.ai" -name '*.md')
  done
  (( missing == 0 )) && pass "P2-G4 all repo .ai/ paths resolve" \
                     || bad "P2-G4 unresolved paths above"
}

# --- P2-G5: repo symlinks are correct and untracked --------------------------
p2g5() {
  local repo name bad_link=0 tracked
  for repo in "${P2_REPOS[@]}"; do
    [[ -f "$repo/.ai/AGENTS.md" ]] || continue
    for name in CLAUDE.md AGENTS.md GEMINI.md; do
      [[ "$(readlink "$repo/$name" 2>/dev/null)" == ".ai/AGENTS.md" ]] \
        || { printf '        %s/%s wrong or missing\n' "$repo" "$name"; bad_link=1; }
      tracked="$(git -C "$repo" ls-files "$name" 2>/dev/null || true)"
      [[ -z "$tracked" ]] || { printf '        %s/%s still tracked\n' "$repo" "$name"; bad_link=1; }
    done
  done
  (( bad_link == 0 )) && pass "P2-G5 repo links correct and untracked" \
                      || bad "P2-G5 link problems above"
}

# --- P2-G6: coverage matrix has no unverified row ---------------------------
p2g6() {
  local f=.ai/_migration-coverage-p2.md
  [[ -f "$f" ]] || { bad "P2-G6 $f missing"; return; }
  local open; open=$($GREP -c '| *no *|' "$f" || true)
  (( open == 0 )) && pass "P2-G6 migration coverage complete" \
                  || bad "P2-G6 $open unverified rows in $f"
}

# --- P2-G7: repo diffs touch only agent context ------------------------------
p2g7() {
  local repo files offenders=0
  for repo in "${P2_REPOS[@]}"; do
    files="$(git -C "$repo" diff --name-only HEAD~1..HEAD 2>/dev/null || true)"
    while read -r f; do
      [[ -z "$f" ]] && continue
      case "$f" in
        .ai/*|.gitignore|README.md|CLAUDE.md|AGENTS.md|GEMINI.md) ;;
        *) printf '        %s: %s\n' "$repo" "$f"; offenders=1 ;;
      esac
    done <<< "$files"
  done
  (( offenders == 0 )) && pass "P2-G7 repo diffs touch only agent context" \
                       || bad "P2-G7 out-of-scope files above"
}
```

Append the calls at the bottom, after `g6`:

```bash
p2g1
p2g2
p2g3
p2g4
p2g5
p2g6
p2g7
```

- [ ] **Step 7: Widen P1's `g2` to cover the repos**

The existing `g2` excludes `--exclude-dir=back` and `--exclude-dir=front`. `p2g2` now covers
those trees precisely, so leave `g2` as it is — the two together satisfy spec goal `P2-G2`. Add
one comment line above `g2` recording why the exclusion stays:

```bash
# back/ and front/ are excluded here and covered precisely by p2g2 (their .ai/ and README).
```

- [ ] **Step 8: Run the gates and record the expected failures**

Run: `scripts/ai-verify.sh; echo "exit=$?"`
Expected: all P1 checks `ok`; `P2-G1` FAIL (no repo trees yet), `P2-G3` FAIL (missing files),
`P2-G6` FAIL (no matrix yet), `exit=1`. `P2-G2`, `P2-G4`, `P2-G5`, `P2-G7` should pass
vacuously. Any other failure is a bug in the script — fix it now, not later.

- [ ] **Step 9: Commit**

```bash
git add .ai/services scripts/ai-link.sh scripts/ai-verify.sh
git commit -m "docs(ai): add service map and external contracts"
```

---

## Task 2: `ms-banks` — the pattern-setter

**This task is a review checkpoint.** Eight repos are filled from the shape it establishes. Do
not start task 3 until it is approved.

**Files:**
- Create: `back/ms-banks/.ai/AGENTS.md`, `back/ms-banks/.ai/references/{DOMAIN,API,EVENTS}.md`
- Modify: `back/ms-banks/.gitignore`
- Delete: `back/ms-banks/CLAUDE.md` (untracked; snapshot exists from task 0)
- Source: `docs/specs/services/ms-banks.md` (498 lines), `p2-snapshot/ms-banks.CLAUDE.md`

**Interfaces:**
- Produces: the file shape, heading set and header line every later repo task reuses —
  `.ai/AGENTS.md` with sections `## Repo` / `## Package tree` / `## Load-bearing facts` /
  `## Read when` / `## Global rules`, and each reference opening with a one-line scope
  statement naming what it does **not** cover.
- Consumes: `scripts/ai-link.sh` repo loop from task 1.

- [ ] **Step 1: Write `back/ms-banks/.ai/AGENTS.md`**

Cap 70 lines. This is the only file in the repo that ever auto-loads, so nothing lazy belongs
in it.

```markdown
# ms-banks

Bank accounts, cards, loans and their installments for the financial-app platform.
Port **8083**, schema **`banks`**. Own git repo — commit banks work here, never from the
parent workspace.

## Package tree

com.financialapp.banks
├── domain            pure — aggregates, VOs, ports, domain services. No Spring.
├── application       use-case implementations, @Transactional lives here
├── web               controllers, DTOs, MapStruct mappers
└── infrastructure    JPA adapters, Kafka, Feign, scheduler

Layer boundaries are enforced by `LayeredArchitectureTest` (ArchUnit) — a violation fails
`mvn verify`, it is not a review opinion.

## Load-bearing facts

- Only aggregate roots have repositories — seven of them; `DOMAIN.md` has the table.
  Installments are reached through their root, never directly.
- `BankNumber` is the 3-digit BCRA entity code that prefixes every `Cbu`. `Cbu` validates both
  modulo-10 check digits on construction.
- ms-banks holds `CHECKING` and `SAVINGS` accounts only. There is no `INVESTMENT` type here —
  an investment account is a derived read-model in ms-investments keyed by `BankNumber`.
- Outbound events go through the transactional outbox (`outbox_event`), published by the
  commons `OutboxRelay`. Never `AFTER_COMMIT`, never a direct send from a use case.
- Inbound consumption is idempotent via `banks.inbound_events` (V16), reached through
  `ProcessedEventGateway`. The V6 `processed_events` table is dead — no entity maps it.

## Read when

| File | Read when |
|---|---|
| `.ai/references/DOMAIN.md` | changing an aggregate, a value object, an enum or a migration |
| `.ai/references/API.md` | adding or changing an endpoint, a DTO or an error code |
| `.ai/references/EVENTS.md` | touching Kafka, the outbox, a scheduled job or a Feign call |

## Global rules

R1–R18, the four workflow modes, the tech stack, the response envelope and the exception
hierarchy live in the **parent workspace** at `.ai/references/`. They are not duplicated here.
Working in this repo without the parent workspace present means working without the rules —
open `financial-app/` as the project root.

Human onboarding and how to run this service: `README.md`.
```

- [ ] **Step 2: Write `back/ms-banks/.ai/references/DOMAIN.md`**

Cap 180. Migrate from `docs/specs/services/ms-banks.md` sections *Domain Model*,
*Aggregates and Value Objects*, *Enumerations & Domain Services*, *CBU / BankNumber Contract*,
*Entity-Relationship Diagram*, *Flyway Migrations*. Structure:

```markdown
# ms-banks — domain

Aggregates, value objects, invariants and schema. Endpoints: `API.md`. Messaging: `EVENTS.md`.
Shared VOs (`Money`, `Cbu`, `BankNumber`): parent `.ai/references/APP_STRUCTURE.md`.

## Aggregates
<one table: aggregate · root entity · owned entities · repository · key invariant>

## Value objects
<table: VO · what it wraps · validation it enforces — service-local VOs only>

## Enumerations
<table: enum · values · what decides the value>

## Domain services
<table: service · the single decision it owns>

## ERD
<compact mermaid erDiagram — entities and cardinalities only, no column lists>

## Schema `banks`
<table: migration file · what it adds — newest last>
```

The annotated ERD with column detail stays in `docs/specs/services/ms-banks.md` (task 11). The
compact one here exists so a model can see cardinality without a 130-line diagram.

- [ ] **Step 3: Write `back/ms-banks/.ai/references/API.md`**

Cap 120. Migrate the eight `### *Controller` endpoint tables. Structure:

```markdown
# ms-banks — API

Endpoints and error codes. Envelope shape, exception hierarchy and the DomainError → HTTP
mapping: parent `.ai/references/APP_STRUCTURE.md` — not repeated here.

## Endpoints
<one table for all controllers: method · path · purpose · error codes>

## DomainError catalog
<table: slug · HTTP status · when it is thrown>
```

Collapse the eight per-controller tables into one, sorted by path. The per-controller split is
a documentation habit, not information — the path already carries it.

- [ ] **Step 4: Write `back/ms-banks/.ai/references/EVENTS.md`**

Cap 60. Migrate *Kafka Integration*, *Scheduled Jobs*, *External Service Calls*.

```markdown
# ms-banks — messaging and jobs

## Published
<table: ce_type · topic · when emitted · payload fields>

## Consumed
<table: ce_type · handler · idempotency key · DLT behaviour>

## Scheduled jobs
<table: job · cron · what it does>

## Outbound calls
<table: target service · endpoint · why>
```

- [ ] **Step 5: Update `.gitignore` and drop the old file**

`CLAUDE.md` and `.claude/` are already ignored in this repo. Add the two missing names next to
them:

```bash
cd back/ms-banks
printf 'AGENTS.md\nGEMINI.md\n' >> .gitignore
rm CLAUDE.md
```

- [ ] **Step 6: Generate the links and verify**

```bash
cd ../..              # back to the parent workspace root
scripts/ai-link.sh | grep ms-banks
```

Expected: three `link` lines for `back/ms-banks/{CLAUDE,AGENTS,GEMINI}.md -> .ai/AGENTS.md`,
and eight repos still `skip`.

```bash
readlink -f back/ms-banks/CLAUDE.md
```

Expected: the absolute path of `back/ms-banks/.ai/AGENTS.md`.

- [ ] **Step 7: Check the caps and the scope**

```bash
wc -l back/ms-banks/.ai/AGENTS.md back/ms-banks/.ai/references/*.md
git -C back/ms-banks status --short
```

Expected: 70/180/120/60 respected; status shows only `.ai/` and `.gitignore` (`CLAUDE.md` was
untracked, so its removal does not appear).

- [ ] **Step 8: Confirm no rule text leaked into the repo**

```bash
grep -rniE 'never (run )?git push|Co-Authored-By|conventional commit|@Transactional in the' \
  back/ms-banks/.ai/ || echo "clean"
```

Expected: `clean`, except the `@Transactional` mention inside the package tree, which is a
layering fact, not a rule restatement. Anything else means R4 was violated — delete it and
point at the parent instead.

- [ ] **Step 9: Commit**

```bash
git -C back/ms-banks add .ai .gitignore
git -C back/ms-banks commit -m "docs(ai): add repo-local agent context"
```

- [ ] **Step 10: Stop for review**

Do not proceed to task 3. Present the four files and the `wc -l` output for approval.

---

## Tasks 3–9: the six remaining backend services

Each task is self-contained and follows the ten steps of task 2 with its own sources, facts and
caps. The heading set is identical; only the content differs. For every repo below:

- **the shape to copy is the committed `back/ms-banks/.ai/` tree (`0aea3c3`), not the drafts in
  Task 2's text.** Read those four files first;
- **the idempotency table is repo-specific.** Find it from that repo's own migrations and its
  `*EventEntity`; never carry ms-banks' answer across (see the corrections section);
- **no fact appears in both `AGENTS.md` and a `references/` file.** `AGENTS.md` carries what is
  load-bearing on every task in the repo and points at the rest;
- sources are `docs/specs/services/<svc>.md` and `p2-snapshot/<repo>.CLAUDE.md`, but **the code
  outranks both** — those specs had drifted, which is why P2 exists;
- `.gitignore` gains `AGENTS.md` and `GEMINI.md`;
- the local `CLAUDE.md` is removed **after** `.ai/` is written;
- for the five repos that track them, `AGENTS.md` and `GEMINI.md` are removed from the index
  first — see the per-task step below;
- the commit is `git -C <repo> add .ai .gitignore && git -C <repo> commit -m "docs(ai): add repo-local agent context"`.

### Task 3: `ms-finances`

**Files:** create `back/ms-finances/.ai/AGENTS.md` + `references/{DOMAIN,API,EVENTS}.md`;
modify `.gitignore`; delete `CLAUDE.md`.
**Source:** `docs/specs/services/ms-finances.md` (465 lines).

**Facts that must appear in `AGENTS.md`:** port 8082, schema `finances`; the
account-to-account model — a transaction carries `fromCbu` and `toCbu`, and its kind
(income/expense/transfer) is **derived from ownership at read time**, never stored; `Money` is
always positive-magnitude, direction comes from the CBU pair; cursor paging and the classifier
introduced on the current branch.
**DOMAIN.md:** `Transaction`, `Category`, `Budget` aggregates, the derivation rule, the
classifier's inputs, Flyway list.
**API.md:** transaction and category endpoints, the dual `PageResult` shape (offset and
cursor), DomainError slugs.
**EVENTS.md:** publishes `finances.transaction.created`; consumes `banks.account.*`; the
transactional outbox as in ms-banks. **Read this repo's own migrations and its `*EventEntity` to
find its idempotency table** — do not copy ms-banks' answer, and do not write `processed_events`
without confirming an entity maps it (see the corrections section).

- [ ] Write the four files · [ ] `printf 'AGENTS.md\nGEMINI.md\n' >> back/ms-finances/.gitignore`
- [ ] `rm back/ms-finances/CLAUDE.md` · [ ] `scripts/ai-link.sh | grep ms-finances` shows three `link` lines
- [ ] `wc -l` within caps · [ ] `git -C back/ms-finances status --short` shows only `.ai/` and `.gitignore`
- [ ] Commit with the message above

### Task 4: `ms-gateway`

**Source:** `docs/specs/services/ms-gateway.md` (129 lines — the thinnest).
**Tracked-symlink cleanup required.**

**Facts for `AGENTS.md`:** port 8080; it is the only public entry point; auth cookies
`access_token` (24h, path `/api`), `refresh_token` (7d, path `/api/v1/auth/refresh`),
`user_info` (readable), `XSRF-TOKEN`; the frontend echoes `X-XSRF-TOKEN` on writes and auth
endpoints are exempt; the gateway injects `X-User-Id` downstream; BFF composition added on the
current branch.
**DOMAIN.md** is thin here — route definitions and filter order rather than aggregates. Keep
the filename for consistency and say so in its first line.
**API.md:** the route table (path prefix → service) and the auth endpoints the gateway owns.
**EVENTS.md:** none published or consumed — state that explicitly in one line rather than
omitting the file, so a model learns it in the file it opened.

- [ ] `git -C back/ms-gateway rm --cached AGENTS.md GEMINI.md`
- [ ] Write the four files · [ ] `printf 'AGENTS.md\nGEMINI.md\n' >> back/ms-gateway/.gitignore`
- [ ] `rm back/ms-gateway/CLAUDE.md` · [ ] `scripts/ai-link.sh | grep ms-gateway` shows three `link` lines
- [ ] `git -C back/ms-gateway status --short` shows `.ai/`, `.gitignore`, and deletions of `AGENTS.md`/`GEMINI.md`
- [ ] Commit with the message above

### Task 5: `ms-investments`

**Source:** `docs/specs/services/ms-investments.md` (535 lines — the largest).
**Tracked-symlink cleanup required.**

**Facts for `AGENTS.md`:** port 8086, schema `investments`; holdings are keyed to `BankNumber`;
the investment account is a **derived read-model** (Σ price × quantity), not a stored balance,
and the `INVESTMENT` account type was deleted from ms-banks in 2026-06; broker fee schedules
and the FX view added on the current branch.
**DOMAIN.md:** `Holding`, `Quote`, `FeeSchedule`, the derived-view computation, Flyway list.
Watch the 180 cap here — if the source will not fit, cut the narrative first and the tables
last.
**API.md:** holdings, quotes, the derived view endpoint, FX endpoints.
**EVENTS.md:** consumes `banks.account.updated`; the quote refresh job.

- [ ] `git -C back/ms-investments rm --cached AGENTS.md GEMINI.md`
- [ ] Write the four files · [ ] `printf 'AGENTS.md\nGEMINI.md\n' >> back/ms-investments/.gitignore`
- [ ] `rm back/ms-investments/CLAUDE.md` · [ ] `scripts/ai-link.sh | grep ms-investments` shows three `link` lines
- [ ] `wc -l` within caps · [ ] status shows only the four allowed paths
- [ ] Commit with the message above

### Task 6: `ms-notifications`

**Source:** `docs/specs/services/ms-notifications.md` (370 lines).
**Tracked-symlink cleanup required.**

**Facts for `AGENTS.md`:** port 8084, schema `notifications`; it is a fan-in consumer — it
subscribes to domain events from several services and publishes none; SSE is the delivery
channel to the frontend, email is the fallback; per-category preferences added on the current
branch.
**DOMAIN.md:** `Notification`, `NotificationPreference`, category enum, Flyway list.
**API.md:** the SSE endpoint and its content type, preference CRUD, mark-read.
**EVENTS.md:** the full consumed list with handler per `ce_type`, idempotency, DLT.

- [ ] `git -C back/ms-notifications rm --cached AGENTS.md GEMINI.md`
- [ ] Write the four files · [ ] `printf 'AGENTS.md\nGEMINI.md\n' >> back/ms-notifications/.gitignore`
- [ ] `rm back/ms-notifications/CLAUDE.md` · [ ] `scripts/ai-link.sh | grep ms-notifications` shows three `link` lines
- [ ] `wc -l` within caps · [ ] status shows only the four allowed paths
- [ ] Commit with the message above

### Task 7: `ms-upload`

**Source:** `docs/specs/services/ms-upload.md` (189 lines).
**Tracked-symlink cleanup required.**

**Facts for `AGENTS.md`:** port 8085, schema `upload`; MinIO is the object store and the bucket
comes from an env var; a statement import is a **run** with a reconciliation state machine,
added on the current branch.
**DOMAIN.md:** `ImportRun` and its states, `UploadedFile`, Flyway list.
**API.md:** upload, run status, reconciliation endpoints, size and content-type limits.
**EVENTS.md:** publishes `upload.import.completed`; MinIO is a call, not an event — say which
is which.

- [ ] `git -C back/ms-upload rm --cached AGENTS.md GEMINI.md`
- [ ] Write the four files · [ ] `printf 'AGENTS.md\nGEMINI.md\n' >> back/ms-upload/.gitignore`
- [ ] `rm back/ms-upload/CLAUDE.md` · [ ] `scripts/ai-link.sh | grep ms-upload` shows three `link` lines
- [ ] `wc -l` within caps · [ ] status shows only the four allowed paths
- [ ] Commit with the message above

### Task 8: `ms-users`

**Source:** `docs/specs/services/ms-users.md` (312 lines).
**Tracked-symlink cleanup required.**

**Facts for `AGENTS.md`:** port 8081, schema `users`; it owns identity and issues nothing —
cookie minting is the gateway's; sessions and preferences added on the current branch;
change-password is in scope per the Wave 0 decision.
**DOMAIN.md:** `User`, `Session`, `Preference`, password hashing policy, Flyway list.
**API.md:** auth-adjacent endpoints this service owns vs those the gateway owns — the split is
the thing an implementer gets wrong, so state it in one line at the top.
**EVENTS.md:** publishes `users.user.created`; consumes nothing.

- [ ] `git -C back/ms-users rm --cached AGENTS.md GEMINI.md`
- [ ] Write the four files · [ ] `printf 'AGENTS.md\nGEMINI.md\n' >> back/ms-users/.gitignore`
- [ ] `rm back/ms-users/CLAUDE.md` · [ ] `scripts/ai-link.sh | grep ms-users` shows three `link` lines
- [ ] `wc -l` within caps · [ ] status shows only the four allowed paths
- [ ] Commit with the message above

### Task 9: `back/financial-app-parent` — BOM and commons

Shape exception: one reference, not three (spec §5.1).

**Files:** create `.ai/AGENTS.md` + `.ai/references/COMMONS.md`; modify `.gitignore`; delete
`CLAUDE.md`.
**Source:** `p2-snapshot/financial-app-parent.CLAUDE.md` (29 lines) plus the modules themselves —
there is no `docs/specs/services/` file for this repo.

**Facts for `AGENTS.md`:** not a runtime service, no port, no schema; it is the Maven BOM plus
`commons-core`, `commons-web`, `commons-messaging`; **it must reach the parent repo's `master`
before any service's CI can consume a new version** (this is the fact that most often breaks a
build); the domain-model branch is current.
**COMMONS.md:** what each of the three modules provides — `ApiResponse` envelope and
`ErrorCode` in core, `ApiExceptionHandler` and `@ApiErrorCodes` in web, CloudEvents binding,
`OutboxRelay` and `ProcessedEventGateway` in messaging. Shared value objects are **pointed at**
in the parent workspace's `.ai/references/APP_STRUCTURE.md`, never restated (P1 moved them
there deliberately).

- [ ] Write the two files · [ ] `printf 'AGENTS.md\nGEMINI.md\n' >> back/financial-app-parent/.gitignore`
- [ ] `rm back/financial-app-parent/CLAUDE.md`
- [ ] `scripts/ai-link.sh | grep financial-app-parent` shows three `link` lines
- [ ] `wc -l` shows AGENTS.md ≤70, COMMONS.md ≤120
- [ ] `grep -n 'APP_STRUCTURE' back/financial-app-parent/.ai/references/COMMONS.md` returns a pointer line
- [ ] Commit with the message above

---

## Task 10: `front/financial-app`

Shape exception: `ROUTES.md`, `API_CLIENT.md`, `UI_STATE.md` (spec §5.1).

**Files:** create `front/financial-app/.ai/AGENTS.md` +
`.ai/references/{ROUTES,API_CLIENT,UI_STATE}.md`; modify `.gitignore`; delete `CLAUDE.md`.
**Source:** `docs/specs/services/frontend.md` (286 lines), `p2-snapshot/financial-app.CLAUDE.md`.

**Interfaces:**
- Produces: the front-end variant of the `Read when` table, which `p2g1` and `p2g3` already
  expect by exactly these three filenames.

- [ ] **Step 1: Write `.ai/AGENTS.md`**

Cap 70. Facts: Next.js app on port 3000; every call goes through the gateway, never to a
service directly; auth is cookie-based and the app never reads `access_token` — only
`user_info`; writes must echo `X-XSRF-TOKEN`; design tokens landed on the current branch.
`Read when` table naming the three references.

- [ ] **Step 2: Write `.ai/references/ROUTES.md`**

Cap 120. From *Folder Tree*, *Routing and Layouts*, *Dashboard layout detail*, *Middleware*,
*Component Areas*: the route tree with its layouts, what `middleware.ts` protects and how it
decides, and where components live.

- [ ] **Step 3: Write `.ai/references/API_CLIENT.md`**

Cap 100. From *API Client*, *apiFetch behavior*, *401 → refresh → retry*, *Domain API modules*,
*Auth Helpers*, *Forms*, *Notifications (SSE)*: `apiFetch`'s contract, the refresh-retry
sequence as a compact mermaid `sequenceDiagram`, the module-per-domain layout, and how the
`ApiResponse` envelope is unwrapped.

- [ ] **Step 4: Write `.ai/references/UI_STATE.md`**

Cap 80. From *State Management*: what belongs in TanStack Query (server state, keys,
invalidation convention) vs Zustand (`lib/store/ui.store.ts`), and the rule that decides. Omit
*Recent UX Fixes (2026-06-12)* — that is history and stays in the human page.

- [ ] **Step 5: Gitignore, remove, link**

```bash
printf 'AGENTS.md\nGEMINI.md\n' >> front/financial-app/.gitignore
rm front/financial-app/CLAUDE.md
scripts/ai-link.sh | grep front/financial-app
```

Expected: three `link` lines.

- [ ] **Step 6: Verify caps and scope**

```bash
wc -l front/financial-app/.ai/AGENTS.md front/financial-app/.ai/references/*.md
git -C front/financial-app status --short
```

Expected: 70/120/100/80 respected; only `.ai/` and `.gitignore` listed.

- [ ] **Step 7: Commit**

```bash
git -C front/financial-app add .ai .gitignore
git -C front/financial-app commit -m "docs(ai): add repo-local agent context"
```

- [ ] **Step 8: Run the full gate sweep**

Run: `scripts/ai-verify.sh; echo "exit=$?"`
Expected: `P2-G1`, `P2-G3`, `P2-G4`, `P2-G5`, `P2-G7` all `ok`; `P2-G6` still FAIL (no matrix);
`exit=1`. `P2-G2` passes only if no repo `README.md` still links a deleted spec — if it fails,
the offending README is fixed in the repo it belongs to with a follow-up commit
`docs: repoint README to .ai references`.

---

## Task 11: Trim the parent's human service pages

**Files:**
- Modify: `docs/specs/services/{ms-banks,ms-finances,ms-gateway,ms-investments,ms-notifications,ms-upload,ms-users,frontend}.md`

**Interfaces:**
- Consumes: the repo `.ai/` trees from tasks 2–10 — a section is only removed here once its
  facts are provably in a repo file.

- [ ] **Step 1: For each of the eight files, keep only the human remainder**

Keep: the intro/summary paragraph, design rationale, "Key Flow" narratives, dated history such
as *Recent UX Fixes (2026-06-12)*, and the large annotated ERD or sequence diagrams.
Remove: aggregates/VO tables, enum tables, endpoint tables, Kafka tables, scheduled jobs,
folder trees, Flyway lists, CI/CD sections.

Add this header immediately under the title of each file:

```markdown
> Human-facing. Facts an implementer needs live in `back/<svc>/.ai/` — this page holds the
> reasoning behind them and does not restate them. If the two disagree, the repo file wins.
```

- [ ] **Step 2: Delete any page that trims below 30 lines**

Per spec §7.3 this is a per-file judgement. `ms-gateway` (129 source lines) and `ms-upload`
(189) are the likely candidates.

```bash
wc -l docs/specs/services/*.md
```

For any file at or under 30 lines whose remaining content is not genuine rationale:

```bash
git rm docs/specs/services/<svc>.md
```

Then add a `Human page` column entry of `—` for that service in `.ai/services/MAP.md`, so the
absence is deliberate and visible.

- [ ] **Step 3: Verify nothing dangles**

```bash
grep -rn 'docs/specs/services/' .ai docs README.md --include='*.md' \
  | grep -v ai-restructure
```

Every hit must name a file that still exists. Fix any that does not.

- [ ] **Step 4: Commit**

```bash
git add docs/specs/services .ai/services/MAP.md
git commit -m "docs: trim service specs to human content"
```

---

## Task 12: Repoint the parent's references

**Files:**
- Modify: `.ai/AGENTS.md` (services blockquote), `.ai/references/RULES.md` (R18),
  `.ai/references/ARCHITECTURE.md` (AI context layer),
  `docs/specs/2026-07-30-ai-restructure-p1-design.md` (supersession note)

- [ ] **Step 1: Replace the services blockquote in `.ai/AGENTS.md`**

Current text points at `.ai/services/<service>.md`, which P2 never creates. Replace:

```markdown
> **Before reading or editing any file under `back/<service>/` or `front/`, first read
> `back/<service>/.ai/AGENTS.md`.** It carries repo-local facts nothing else duplicates, and
> names the lazy references for that repo. Claude Code loads it automatically through the
> repo's generated `CLAUDE.md`; other tools must read it explicitly.
> Cross-service routing: `.ai/services/MAP.md`. Third-party contracts:
> `.ai/services/EXTERNAL.md`.
```

- [ ] **Step 2: Rewrite R18 in `.ai/references/RULES.md`**

Current body names `.ai/services/`, which no longer holds service files. Replace lines 113–116
with:

```markdown
### R18 — Update the reference and the README after implementing
Every implementation updates that repo's `.ai/` references **and** its `README.md`. The
first is the design record a model reads, the second is the quick-start for a human who
clones only that repo. Update the parent's `docs/specs/services/<svc>.md` only when the
*reasoning* changed — it holds no facts to sync.
```

- [ ] **Step 3: Extend the AI-context-layer section of `ARCHITECTURE.md`**

After the existing paragraph about generated symlinks, add:

```markdown
Context is two-level. The parent `.ai/` holds rules, architecture and cross-service routing;
each service repo holds its own `.ai/AGENTS.md` plus lazy references, tracked by that repo.
`scripts/ai-link.sh` generates the three entry-point symlinks in all ten repos. A service repo
never copies a global rule — it points at the parent, and the parent workspace is required.
```

Also update the repo-layout tree in the same file so `back/` reads:

```
├── back/                       financial-app-parent/ + the 7 ms-* repos, each with .ai/
```

- [ ] **Step 4: Add the supersession note to the P1 design**

At the end of P1 §4.3, append one line — do not rewrite the section:

```markdown
**Superseded 2026-07-31 by P2 §4.3:** nested `CLAUDE.md` auto-load makes the `skills/svc-*`
loaders unnecessary. No such skills were created.
```

- [ ] **Step 5: Verify**

```bash
scripts/ai-verify.sh; echo "exit=$?"
```

Expected: only `P2-G6` fails (`exit=1`). If `G5` (P1's path check) now fails, a link in
`AGENTS.md` points at something task 11 deleted — fix it here.

- [ ] **Step 6: Commit**

```bash
git add .ai/AGENTS.md .ai/references/RULES.md .ai/references/ARCHITECTURE.md \
        docs/specs/2026-07-30-ai-restructure-p1-design.md
git commit -m "docs(ai): repoint service context to repos"
```

---

## Task 13: Coverage matrix, gates, development report

**Files:**
- Create: `.ai/_migration-coverage-p2.md`,
  `docs/reports/master_chore_2026-07-31_ai-restructure-p2.md`

**Interfaces:**
- Consumes: `p2-snapshot/` from task 0 and the trimmed pages from task 11.
- Produces: the artefact `p2g6` asserts on — a table with no row whose Verified column is `no`.

- [ ] **Step 0: Fix the `g2` false positive — required before any sweep can go green**

P1's `g2` passes `--exclude-dir=superpowers`, which never matches the real `.superpowers/`
directory, so agent working files self-match its own grep pattern and `g2` fails on them. Correct
the exclude to `.superpowers` in `scripts/ai-verify.sh`, then confirm `g2` reports `ok`. Without
this, this task's `exit=0` expectation is unreachable and every remaining failure is masked.

- [ ] **Step 1: Build the matrix**

One row per source **section**, not per paragraph (spec §7.10). Format follows P1's
`.ai/_migration-coverage.md`:

```markdown
# P2 migration coverage

Sources: `docs/specs/services/*.md` (8 files) and the nine untracked `CLAUDE.md` files
snapshotted before deletion. `Verified: yes` means the row's content is present at its target,
**or** that it was dropped to a named owner and that owner carries it.

| Source | Section | Target | Verified |
|---|---|---|---|
| `docs/specs/services/ms-banks.md` | Domain Model | `back/ms-banks/.ai/references/DOMAIN.md` | yes |
| `docs/specs/services/ms-banks.md` | CI/CD | DROPPED → `.ai/references/PIPELINE.md` | yes |
| `ms-banks.CLAUDE.md` | Load-bearing rules | DROPPED → `.ai/references/RULES.md` | yes |
| … | | | |
```

Enumerate the sections mechanically so none is missed:

```bash
grep -n '^#\{1,3\} ' docs/specs/services/*.md | wc -l
grep -n '^#\{1,2\} ' "$SNAP"/*.CLAUDE.md | wc -l
```

The matrix must have at least that many rows.

- [ ] **Step 2: Run the full gate sweep**

```bash
scripts/ai-verify.sh; echo "exit=$?"
```

Expected: every check `ok`, `exit=0`. Do not proceed until it is 0.

- [ ] **Step 3: Cold-clone check on one repo**

Proves a fresh clone is not broken by the index changes:

```bash
TMP=$(mktemp -d)
git clone -q --no-hardlinks back/ms-users "$TMP/ms-users"
ls -la "$TMP/ms-users" | grep -E 'CLAUDE|AGENTS|GEMINI' || echo "no entry-point files (expected)"
ls "$TMP/ms-users/.ai/references"
rm -rf "$TMP"
```

Expected: no dangling symlinks — this is the fix for spec §4.6b — and `.ai/references/`
containing `DOMAIN.md API.md EVENTS.md`.

- [ ] **Step 4: Write the development report**

To `docs/reports/master_chore_2026-07-31_ai-restructure-p2.md`, using the template in
`.ai/references/REPORTS_STRUCTURE.md`. The `Files and commits touched` table has ten rows, one
per repo, with the branch and the commit SHA. `Goals` restates `P2-G1`…`P2-G6` from the spec
verbatim with `met` / `not-met` / `partial` and the pasted `ai-verify.sh` output — not a
summary of it. `Contract changes` is empty and the heading stays.

`Follow-ups and deferred work` must carry these, each also routed into `docs/specs/IDEAS.md`:

| Finding | Why it matters |
|---|---|
| No shared `Cbu` in commons — four divergent copies in ms-banks, ms-finances, ms-investments, ms-upload | R4 violation: one concept, four implementations that can drift apart silently |
| `ms-upload` carries an unused `spring-kafka` dependency and an uninjected `BanksClient` Feign interface | Dead wiring that reads as a live integration to anyone scanning the repo |
| ms-banks V6 `processed_events` table exists with no entity mapping it | Dead migration; it already caused one wrong fact in this sub-project |
| Task 2's commit was verified in-session rather than by an independent reviewer | The other eight repos got a reviewer; ms-banks did not. Worth one pass before merge |

- [ ] **Step 5: Commit**

```bash
git add .ai/_migration-coverage-p2.md docs/reports
git commit -m "docs(ai): record P2 migration coverage"
```

- [ ] **Step 6: Final scope audit across all ten repos**

```bash
for d in . back/*/ front/financial-app/; do
  printf '%-34s %s\n' "$d" "$(git -C "$d" log --oneline -1)"
done
```

Expected: nine repos show `docs(ai): add repo-local agent context` (or a README follow-up), the
parent shows `docs(ai): record P2 migration coverage`. Nothing is pushed — R11.

---

## Self-review notes

- **Spec coverage.** §4.1 → global constraints + task 1; §4.2 → tasks 2–10; §4.3 → task 12
  step 4; §4.4 → task 1 step 4; §4.5 → the `## Global rules` block in every repo `AGENTS.md`;
  §4.6 → task 0; §4.6b → the `git rm --cached` step in tasks 4–8 and task 13 step 3; §4.7 →
  task 11; §4.8 → task 2 step 8 and the DROPPED rows in task 13; §5.1 exceptions → tasks 9 and
  10; §5.2 → task 1; §6.3 caps → `p2g3`; §7.3 → task 11 step 2; §7.9 → the `P2-` gate prefix.
- **Gate-to-goal mapping.** `P2-G1`→`p2g1`+`p2g5`, `P2-G2`→`p2g2`+`g2`, `P2-G3`→`p2g3`+`p2g4`,
  `P2-G4`→`p2g6`, `P2-G5`→`p2g7`, `P2-G6`→ task 2 step 8 and `p2g2`.
- **Known slack.** `P2-G7` compares `HEAD~1..HEAD`, so it is only meaningful immediately after
  a repo's single P2 commit. A repo needing a README follow-up commit must be checked by hand
  against its pre-P2 SHA.
