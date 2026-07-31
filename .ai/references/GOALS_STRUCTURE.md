# Goal Structure

How to write the goals section of a spec, plan or report. Loaded when planning.

## A goal is not a task

A task is an action taken. A goal is an observable end state that holds after the tasks run.
If a reader cannot check it without reading the diff, it is a task wearing a goal's clothes.

- Task: *Add `BudgetRepository`.*
- Goal: *A user can set a monthly cap per category, and the API rejects an over-cap write.*

The difference matters because tasks can all be completed while the thing the user asked for
still does not work. Goals are what get checked at the end; tasks are only how you get there.

## Form

```
G<n>. <observable outcome> — Verified by: <command or observable>
```

No goal ships without a verification clause. If you cannot name the command, endpoint, log
line or screen that proves it, it is not yet a goal — sharpen it until you can.

```
G3. Over-cap writes are rejected with 409 and code BUDGET_EXCEEDED
    — Verified by: mvn -pl ms-finances verify (BudgetLimitIT), and
      POST /api/v1/finances/transactions over an existing cap returns 409
```

## Constraints

- **3–8 goals per plan.** Fewer means the plan is not saying what it is for; more means it is
  two plans.
- **Each independently verifiable.** Verifying one must not require another to have passed.
- **Mapped many-to-many onto tasks — never one goal per task.** One goal per task is a
  restatement of the task list and adds nothing. A real goal usually spans several tasks, and
  one task often serves several goals.
- **An explicit `Non-goals` list bounds scope.** Name what a reader would reasonably expect and
  is not getting, and why. This is what stops scope creep mid-execution.

## Traceability

The plan states the goals. The development report restates each one verbatim with a status of
`met`, `not-met` or `partial`, plus the pasted evidence — the actual command output, not a
claim that it passed. A goal reported `met` with no evidence is not met.

`partial` is a legitimate outcome and must say which part is missing and where it was routed
(usually `docs/specs/IDEAS.md`). Silently downgrading a goal to make a report look green is
the failure this section exists to prevent.
