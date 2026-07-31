# Report Structure

Three outputs. The first is a reply; the other two are files. Loaded when writing a spec, a
plan, or a development report.

**Every spec and every plan carries at least one diagram** — a tree, a Mermaid flowchart, or
an ER diagram. A document describing structure without showing it is incomplete.

## 1. Standard output reply

The default. Three short paragraphs, no file written:

1. What the issue was.
2. What changed.
3. The result.

Use this for anything that does not warrant a durable record. Most work lands here.

## 2. Spec / plan template

Written to `docs/specs/` or `docs/plans/`.

```markdown
# <name>

## Branches and repositories involved
## Objective
## Connection to related specs or plans
## Diagrams
## What will be done
## Problems to consider
## Goals
## Content references needed to implement
```

- **Branches and repositories involved** — polyrepo: name every repo and the branch in each.
- **Connection to related specs or plans** — link them. A spec with no stated relationship to
  the existing record is usually duplicating one.
- **Problems to consider** — known risks, contradictions found in the code, decisions the user
  must make. Surface these before writing the plan body, not inside it.
- **Goals** — per `.ai/references/GOALS_STRUCTURE.md`, including the `Non-goals` list.
- **Content references needed to implement** — the exact files an implementer must read.

## 3. Development report template

Written to `docs/reports/<from_branch>_<branch_type>_<date>_<name>.md`.

```markdown
# <name>

## Branches and repositories involved
## Objective
## Connection to plans or specs
## Diagrams
## Goals
## What was done
## Problems found
## Files and commits touched
## Verification evidence
## Contract changes
## Follow-ups and deferred work
## Results
## Other references
```

- **Goals** — each goal from the plan, restated verbatim, marked `met` / `not-met` / `partial`.
- **Files and commits touched** — a table, one row per repo:

  | Repo | Branch | Commit |
  |---|---|---|

- **Verification evidence** — the pasted `mvn verify` or test output. Paste it; do not
  summarise it and do not claim a pass you did not run.
- **Contract changes** — endpoints, DTO fields, Kafka event schemas, migrations. An empty
  section is a meaningful statement: nothing downstream broke. Leave the heading in place.
- **Follow-ups and deferred work** — everything found and not fixed, routed into
  `docs/specs/IDEAS.md` so it survives the session.

The last four sections are what make a report auditable rather than narrative. A report
without evidence and contract changes is a story about work, not a record of it.

## Naming

`docs/reports/WAVE00_2026-07-30.md` predates this convention. It is grandfathered and is not
renamed. The naming rule applies to reports written from P1 onward.
