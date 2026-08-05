# ms-banks — Service Spec

> Human-facing. Facts an implementer needs live in `back/ms-banks/.ai/` — this page holds the
> reasoning behind them and does not restate them. If the two disagree, the repo file wins.

## Summary

ms-banks owns the user's financial instruments at the bank level: the bank catalog, bank accounts (CBU-addressed), credit/debit cards with installment schedules, and loans amortised via the French method. It provides a consolidated upcoming-payments view (combining loan and card installments) and a metadata endpoint for form selectors. Domain events are published via a transactional **outbox** (CloudEvents, binary mode) on balance adjustments, low balance, installment payments, and the daily card/loan alerts; the service also consumes `finances.transaction.created` events from ms-finances to keep account balances in sync.

---

## Key Flow: Account Balance Adjustment

This flow covers both the REST path (manual adjustment) and the Kafka-driven path (transaction sync from ms-finances).

```mermaid
sequenceDiagram
    participant Client
    participant AccountController
    participant AdjustBalanceUseCase
    participant Account
    participant AccountRepository
    participant DomainEventPublisher
    participant Kafka

    alt REST — manual adjustment
        Client->>AccountController: POST /api/v1/banks/accounts/{cbu}/balance/adjust?delta=...&currency=...
        AccountController->>AdjustBalanceUseCase: execute(AdjustBalanceCommand)
    else Kafka — transaction sync
        Kafka-->>TransactionEventListener: finances.transaction.created event
        TransactionEventListener->>AdjustBalanceUseCase: execute(AdjustBalanceCommand)
        note over TransactionEventListener: idempotency via ProcessedEvent table
    end

    AdjustBalanceUseCase->>AccountRepository: findByCbu(cbu)
    AccountRepository-->>AdjustBalanceUseCase: Account
    AdjustBalanceUseCase->>Account: debit(amount) or credit(amount)
    Account-->>AdjustBalanceUseCase: AccountAdjustment(updatedAccount, events)
    note over Account: Raises BalanceAdjustedEvent;<br/>LowBalanceEvent if balance < 500
    AdjustBalanceUseCase->>AccountRepository: save(updatedAccount)
    AdjustBalanceUseCase->>DomainEventPublisher: publishAll(events)
    DomainEventPublisher-->>Kafka: banks.account.balance_adjusted / banks.account.low_balance (via outbox relay)
```
