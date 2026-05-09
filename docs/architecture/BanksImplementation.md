# Banks Microservice Architecture (ms-banks)

## 1. System Context
The **`ms-banks`** service is the central hub for the user's financial life, managing real-world banking institutions, accounts, cards, and loans. It is the authority for balances and debt state.

---

## 2. Core Architecture: The Bank Hub

### A. Bank (Institution)
- **Purpose:** A container for all accounts, cards, and loans from a real-world bank (e.g., "Chase").
- **Attributes:** `id`, `name`, `userId`, `logoUrl`, `createdAt`, `updatedAt`.

### B. Account
- **Purpose:** A specific balance-holding entity within a Bank.
- **Attributes:** `id`, `bankId`, `name`, `type` (CHECKING, SAVINGS, INVESTMENT), `balance`, `currency`, `isActive`.
- **Investment Logic:** If type is `INVESTMENT`, the balance is dynamically aggregated from `ms-investments`.

### C. Card
- **Purpose:** A payment instrument linked to an Account.
- **Attributes:** `id`, `accountId`, `brand`, `type`, `expiringDate`, `behavior` (INSTANT_PAYMENT, INSTALLMENTS).
- **Debt Tracking:** For `INSTALLMENTS` cards, track debt and due dates. Payments are manual transactions from an account to the card.

### D. Loan (French Amortization)
- **Purpose:** A debt obligation linked to an Account.
- **Formula:** Uses the **French Amortization System** (Fixed monthly installments).
- **Attributes:** `id`, `accountId`, `principal`, `interestRate` (annual %), `totalInstallments`, `remainingInstallments`, `startDate`.
- **Calculation:** `A = P * [i(1+i)^n] / [(1+i)^n - 1]` where `i` is the monthly rate.

---

## 3. Cross-Service Integrations

### Transaction Integrity (Eventual Consistency)
To prevent "Split-Brain" errors (where a transaction is recorded but the balance isn't updated), the system uses **Kafka-based Event Sourcing**:

1.  **ms-finances:** Saves the `Transaction` entity and publishes `transaction.created`.
2.  **ms-banks:** Listens to `transaction.created`.
    -   **Idempotency:** Checks the `processed_events` table before applying.
    -   **Update:** Adjusts the `Account.balance`.
    -   **Security:** Verifies that the `userId` in the event owns the target account.

### ms-investments (Portfolio Hub)
- **Aggregation:** `ms-banks` queries `ms-investments` via Feign to calculate the total value of "Investment Accounts" in real-time.

### ms-notifications (Alert Hub)
- **Events:** Publishes `CARD_EXPIRING`, `LOAN_DUE`, and `LOW_BALANCE` events to Kafka for user alerts.

---

## 4. Key Security Rules
- **Internal Auth:** Every REST call from other services (e.g., Gateway, Finances) must include the `X-Internal-Token`.
- **Ownership Validation:** Every operation validates that the `X-User-Id` matches the owner of the Bank/Account/Loan.
- **Transactional Outbox:** All Kafka events are published using `@TransactionalEventListener(phase = AFTER_COMMIT)` to ensure they only fire if the database change is permanent.
