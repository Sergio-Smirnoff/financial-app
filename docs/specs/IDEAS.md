# Ideas

A running backlog of future ideas — features, improvements, refactors, and things to keep in
mind. This is **not** a commitment list; it's a scratchpad to capture thoughts before they're
lost. Promote an idea to a real spec + plan (via the brainstorming → writing-plans flow) when
it's ready to build.

## How to use this file

- Add an idea under the right section with a short title + one or two lines of context.
- Optional tags: `[feature]` `[refactor]` `[infra]` `[ux]` `[tech-debt]` `[research]`.
- When an idea becomes real work, move it to **In progress / promoted** with a link to its
  spec in `docs/specs/` (or `docs/superpowers/specs/`), then delete it from the backlog.

## Backlog

### Features
- Add the thesis to the investments
- Add to workflow the use of Notion insead of this Ideas.md, to manage task / features / histories to be done. With this we can track progress, backlog and status of the project
- grafana dashboards and alerts

### Bugs
- Cant create an account with the same name although its a different user, that does not need to be a restriction
- In historic transactions: The table column type, the color of the INCOME pill is not green
- Error in creation of card: - Could be fix with a review of the envelops in all the front -
  POST http://localhost:8080/api/v1/banks/cards 400 (Bad Request)
  apiFetch @ client.ts:39
  (anonymous) @ client.ts:80
  (anonymous) @ cards.ts:14
  (anonymous) @ useCards.ts:24
  (anonymous) @ mutation.ts:190
  (anonymous) @ retryer.ts:155
  (anonymous) @ retryer.ts:221
  execute @ mutation.ts:235
  await in execute
  mutate @ mutationObserver.ts:142
  (anonymous) @ CardFormDialog.tsx:79
  (anonymous) @ createFormControl.ts:1311
  await in (anonymous)
  executeDispatch @ react-dom-client.development.js:16970
  runWithFiberInDEV @ react-dom-client.development.js:871
  processDispatchQueue @ react-dom-client.development.js:17020
  (anonymous) @ react-dom-client.development.js:17621
  batchedUpdates$1 @ react-dom-client.development.js:3311
  dispatchEventForPluginEventSystem @ react-dom-client.development.js:17174
  dispatchEvent @ react-dom-client.development.js:21357
  dispatchDiscreteEvent @ react-dom-client.development.js:21325
  CardFormDialog.tsx:83 Failed to submit card form: ApiError: Card number must be exactly 16 digits
      at apiFetch (client.ts:71:11)
  Not showing an error in the card, not catched

- In the principal dashbaord, the Income vs expense is just showing 1 currency data with the label USD. Which is not true
- Cant create 2 investment accounts in a bank, show be allowed 1 investment account per currency per bank per user. 
POST http://localhost:8080/api/v1/banks/cards 400 (Bad Request)
apiFetch @ client.ts:39
(anonymous) @ client.ts:80
(anonymous) @ cards.ts:14
(anonymous) @ useCards.ts:24
(anonymous) @ mutation.ts:190
(anonymous) @ retryer.ts:155
(anonymous) @ retryer.ts:221
execute @ mutation.ts:235
await in execute
mutate @ mutationObserver.ts:142
(anonymous) @ CardFormDialog.tsx:79
(anonymous) @ createFormControl.ts:1311
await in (anonymous)
executeDispatch @ react-dom-client.development.js:16970
runWithFiberInDEV @ react-dom-client.development.js:871
processDispatchQueue @ react-dom-client.development.js:17020
(anonymous) @ react-dom-client.development.js:17621
batchedUpdates$1 @ react-dom-client.development.js:3311
dispatchEventForPluginEventSystem @ react-dom-client.development.js:17174
dispatchEvent @ react-dom-client.development.js:21357
dispatchDiscreteEvent @ react-dom-client.development.js:21325
CardFormDialog.tsx:83 Failed to submit card form: ApiError: Card number must be exactly 16 digits
    at apiFetch (client.ts:71:11)

- Cant make a transfer to an investment account
- The edit holding is broken, Investment account cannot be set there![alt text](image.png)


### Improvements & refactors
- Change all the JWT system and the auth tokens
- Add or reincert kafka topics, specific for each emmision and notification track all that. Fix the kafka headers 
- refactor some pages of the front end: banks, investments, categories, configuration, uploads

### Infrastructure & tooling
- review network

### Research / open questions
- mail server
- message connection
- uploads migration, best way to reimplemented

### Tech-debt — code/canon divergences (found in 2026-06-04 doc QA)
- ms-finances names its exception advice `DomainExceptionHandler`; canon (rules.md) is
  `GlobalExceptionHandler`. Rename. `[refactor]` `[tech-debt]`
- ms-investments `InfrastructureException` lives in `infrastructure/exception/` and extends
  `RuntimeException`; canon is `domain/exception/` extending `DomainException` (as in ms-banks).
  Migrate so catch-ordering in use cases is correct. `[refactor]` `[tech-debt]`
- Frontend `types/notifications.ts` `NotificationType` union declares only 6 of the backend's
  10 values (missing `CARD_EXPIRING`, `LOW_BALANCE`, `TRANSFER_SENT`, `TRANSFER_RECEIVED`) —
  those notifications fail TS narrowing. `[ux]` `[tech-debt]`
- Frontend declares numeric fields as `number` but ms-investments serialises money as `String`
  over the wire — type mismatch for callers. Align frontend types. `[ux]` `[tech-debt]`

## In progress / promoted

- Host the application on the cloud → researched, spec: [2026-06-05-cloud-hosting-research.md](../superpowers/specs/2026-06-05-cloud-hosting-research.md)
- Java 25 migration → researched, decision: Boot 4.0 + SC 2025.1 + Java 25, spec: [2026-06-05-java-25-spring-boot-4-migration.md](../superpowers/specs/2026-06-05-java-25-spring-boot-4-migration.md)
- GitHub Actions CI pipeline + branch protections → IMPLEMENTED 2026-06-05, spec: [2026-06-05-github-actions-ci-pipeline-design.md](../superpowers/specs/2026-06-05-github-actions-ci-pipeline-design.md)

---

[Master](00-master.md)
