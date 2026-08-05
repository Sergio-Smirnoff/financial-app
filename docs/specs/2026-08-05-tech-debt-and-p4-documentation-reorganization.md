# Tech Debt Cleanup & Sub-project P4 Documentation Reorganization

## Branches and repositories involved

- `financial-app` (parent)
- `back/financial-app-parent` (`feat/commons-domain-model`)
- `back/ms-banks` (`feat/fee-schedules-installments`)
- `back/ms-finances` (`feat/cursor-paging-classifier`)
- `back/ms-investments` (`feat/broker-fee-schedules-fx-view`)
- `back/ms-upload` (`feat/import-run-reconciliation`)

---

## Objective

1. **Consolidate `Cbu` Value Object:** Extract `Cbu.java` into `commons-core` (`com.financialapp.commons.core.domain.model.Cbu`) to eliminate 4 divergent implementations across `ms-banks`, `ms-finances`, `ms-investments`, and `ms-upload`.
2. **Clean up `ms-upload` Dead Wiring:** Remove unused `spring-kafka` dependency from `ms-upload/pom.xml` and remove un-injected `BanksClient.java`.
3. **Resolve `ms-banks` Unmapped Table:** Document V6 `processed_events` legacy table status in `ms-banks` agent context.
4. **Execute Sub-project P4:** Reorganize human-facing `docs/`, unfreeze/archive `docs/superpowers/`, and update `docs/specs/IDEAS.md`.

---

## Content References

- `back/financial-app-parent/commons-core/src/main/java/com/financialapp/commons/core/domain/model/`
- `.ai/references/ARCHITECTURE.md`
- `docs/specs/IDEAS.md`
