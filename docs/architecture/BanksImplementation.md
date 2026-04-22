# INFRASTRUCTURE AGENT PROMPT: Financial App - Banks Microservice Redesign

## 1. System Context & Goal
You are an expert infrastructure and backend architect. Your mission is to redesign the existing `ms-cards` microservice into a robust **`ms-banks`** service. This service will act as the central hub for the user's financial life, managing real-world banking institutions, accounts, cards, and loans.

**Current Tech Stack:**
- **Backend:** Java 21, Spring Boot 3.4, Spring Cloud Gateway.
- **Database:** PostgreSQL 17 (Shared instance, separate schemas).
- **Messaging:** Apache Kafka (Event-driven notifications).
- **Communication:** Internal REST (via Feign) and Kafka.
- **Parent:** All services inherit from `financial-app-parent`.

---

## 2. Core Architecture: The Bank Hub
The `ms-banks` service manages the following entity hierarchy:

### A. Bank (Institution)
- **Purpose:** A container for all accounts, cards, and loans from a real-world bank (e.g., "Chase").
- **Attributes:** `id`, `name`, `userId`, `logoUrl` (optional), `createdAt`, `updatedAt`.

### B. Account
- **Purpose:** A specific balance-holding entity within a Bank.
- **Attributes:** `id`, `bankId`, `name`, `type` (CHECKING, SAVINGS, INVESTMENT), `balance`, `currency`, `isActive`.
- **Investment Logic:** If type is `INVESTMENT`, the balance must be dynamically aggregated or synced from `ms-investments`.

### C. Card
- **Purpose:** A payment instrument linked to an Account.
- **Naming Rule:** String concatenation of `bankName` + `brand` (Visa/Mastercard) + `type` (Silver, Gold, Black, Platinum).
- **Attributes:** `id`, `accountId`, `brand`, `type`, `expiringDate`, `behavior` (INSTANT_PAYMENT, INSTALLMENTS).
- **Installment Tracking:** For `INSTALLMENTS` cards, track debt and due dates. Payments are manual transactions from an account to the card.

### D. Loan
- **Purpose:** A debt obligation linked to an Account.
- **Attributes:** `id`, `accountId`, `description`, `totalAmount`, `installmentAmount`, `totalInstallments`, `paidInstallments`, `nextPaymentDate`.
- **Migration:** This logic must be moved from the current `ms-finances` into `ms-banks`.

---

## 3. Cross-Service Integrations

### ms-finances (Transaction Hub)
- **Transactions:** Must support an optional `accountId`.
- **CASH Logic:** Any transaction without an `accountId` is labeled as `CASH`.
- **Operations:** Support "Account-to-Account" transfers and "Cash-to-Account" (Deposits/Withdrawals).
- **Dashboard API:** Update to provide an average summary of accounts, expenses, and income. If multiple currencies exist, separate values with `\n`.

### ms-investments (Portfolio Hub)
- **Connection:** Holdings in `ms-investments` should optionally link to a `bankAccountId` in `ms-banks`.
- **Aggregation:** `ms-banks` queries `ms-investments` to calculate the total value of "Investment Accounts".

### ms-notifications (Alert Hub)
- **Bank Notifications:** A filtered view showing only events where `entityType` matches BANK, ACCOUNT, CARD, or LOAN.
- **Events:** Publish `CARD_EXPIRING`, `LOAN_DUE`, and `LOW_BALANCE` events to Kafka.

---

## 4. User Stories & Use Cases

### UC1: The Multi-Account Bank
**Story:** "As a user, I want to create a 'Chase' Bank and add my 'Checking' and 'Savings' accounts so I can see my total liquidity in one place."
**Requirement:** CRUD for Banks and Accounts. Selection of a Bank shows all child entities.

### UC2: Card Selection & Branding
**Story:** "As a user, I want to add a 'Visa Platinum' card to my Chase account so I can track my spending."
**Requirement:** Card name auto-generates (e.g., "Chase Visa Platinum"). Track expiration date to trigger notifications.

### UC3: The "CASH" Transaction
**Story:** "As a user, I want to record a coffee purchase paid with physical bills."
**Requirement:** Transaction is created in `ms-finances` without a `bankAccountId`. System labels it as `CASH`.

### UC4: Dashboard Liquidity
**Story:** "As a user, I want to see my total net worth across all banks and my physical cash."
**Requirement:** Dashboard aggregates `ms-banks` (Accounts) + `ms-finances` (CASH entries).

---

## 5. Implementation Phases

### Phase 1: Infrastructure & Rename
1. Refactor/Rename `ms-cards` to `ms-banks`.
2. Setup PostgreSQL schema `banks`.
3. Implement `Bank` and `Account` entities and REST controllers.

### Phase 2: Domain Migration
1. Move `Loan` and `LoanInstallment` entities/logic from `ms-finances` to `ms-banks`.
2. Move `CardExpense` logic from `ms-finances` to `ms-banks` and refactor into the new `Card` model.
3. Update `ms-finances` schema to remove these tables after data migration.

### Phase 3: Transaction Linking
1. Update `ms-finances.Transaction` to include `accountId`.
2. Implement Feign clients for `ms-banks` to validate accounts during transaction creation.
3. Implement the `CASH` label logic in the `ms-finances` service layer.

### Phase 4: Investment & Notification Logic
1. Create a "Sync" or "Query-on-demand" bridge between `ms-banks` and `ms-investments`.
2. Update `ms-notifications` consumers to support bank-specific filtering.

---

## 6. Technical Constraints
- **Strict Isolation:** `ms-banks` owns the Bank/Account/Card/Loan data. `ms-finances` owns Transaction data.
- **Manual Payments:** Paying a card installment or loan must be a `Transaction` entry in `ms-finances` that updates the entity state in `ms-banks`.
- **Validation:** Transactions targeting an account must verify the account exists in `ms-banks` via internal API.
- **Consistency:** Use `@Transactional` and ensure Kafka events are sent only after DB commits.

---

**Mission Directive:** Build the foundation of `ms-banks` following these specifications. Start with the database migrations and the core entity relationships.
