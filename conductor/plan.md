# Banks Migration — Plan 07: UI/UX Refactor

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Completely overhaul the Banks UI to be more spacious, paginated, and physically representative, while integrating quick actions (Transfer, Deposit, Withdraw) directly into the accounts. Remove redundant sidebar items.

**Architecture:** The `/banks` route will show a paginated grid of bank cards (max 6 per page). Each card displays separated currency totals, asset counts, and specific notifications. Clicking a bank navigates to a detail page `/banks/[bankId]` where accounts take full width. Cards inside accounts will look like physical credit cards. `ms-banks` will be updated to calculate and return these totals to avoid frontend over-fetching.

**Tech Stack:** Java 21, Spring Boot 3.4.2, Next.js 15, React 19, Tailwind CSS, shadcn/ui.

---

## Pre-flight Check
- [ ] On branch `feat/ui-ux-refactor` or `banks-migration-07-ui-ux`
- [ ] Plan 06 executed and merged
- [ ] All tests passing

---

### Task 1: Update BankResponse and BankService in ms-banks

**Files:**
- Modify: `back/ms-banks/src/main/java/com/financialapp/banks/model/dto/response/BankResponse.java`
- Modify: `back/ms-banks/src/main/java/com/financialapp/banks/service/BankService.java`
- Modify: `back/ms-banks/src/test/java/com/financialapp/banks/service/BankServiceTest.java`

- [ ] **Step 1: Add summary fields to BankResponse**
Add `Map<String, BigDecimal> totalBalances` (e.g., {"ARS": 15000, "USD": 500}), `int accountsCount`, `int cardsCount`, and `int loansCount` to the `BankResponse` record.

- [ ] **Step 2: Update BankService to calculate totals**
In `BankService.accountsFor()`, after fetching `List<AccountResponse>`, calculate the `totalBalances` by grouping by currency and summing the balances.
Also calculate `accountsCount` (size of accounts list).
*Note: To avoid N+1 queries for cards and loans, inject `CardRepository` and `LoanRepository`, and count them by `accountId` in the stream, or add `List<CardResponse>` and `List<LoanResponse>` to `AccountResponse` if that makes sense, but counting is safer for payload size.*
For now, inject `CardRepository` and `LoanRepository`. Count cards and loans for each account and sum them up for the bank.

- [ ] **Step 3: Update BankServiceTest**
Fix tests to accommodate the new fields in `BankResponse`.

- [ ] **Step 4: Commit**
```bash
git add back/ms-banks/src/main/java/com/financialapp/banks/
git commit -m "feat(ms-banks): add summary totals and counts to BankResponse"
```

---

### Task 2: Inject Bank ID into Notifications

**Files:**
- Modify: `back/ms-banks/src/main/java/com/financialapp/banks/scheduler/BankAlertScheduler.java`

- [ ] **Step 1: Update metadata in BankAlertScheduler**
When creating `BankAlertEvent` in `checkCardExpirations`, `checkUpcomingLoanPayments`, and `checkLowBalances`, include `"bankId": <bank_id>` in the JSON metadata string.
You will need to fetch the `Bank` or `bankId` via the `Account`.
For `Card`: `card.getAccountId()` -> `accountRepository.findById()` -> `getBankId()`.
For `LoanInstallment`: `inst.getLoan().getAccountId()` -> ...

- [ ] **Step 2: Commit**
```bash
git add back/ms-banks/src/main/java/com/financialapp/banks/scheduler/
git commit -m "feat(ms-banks): include bankId in alert metadata"
```

---

### Task 3: Refactor Sidebar & Route Structure

**Files:**
- Modify: `front/financial-app/components/layout/Sidebar.tsx`
- Delete: `front/financial-app/app/(dashboard)/transactions/` (or repurpose it as a hidden route if strictly needed, but better to delete from sidebar navigation).
- Create: `front/financial-app/app/(dashboard)/banks/[bankId]/page.tsx`

- [ ] **Step 1: Remove Transactions from Sidebar**
Remove the "Transactions" entry from `NAV_ITEMS` in `Sidebar.tsx`.

- [ ] **Step 2: Create Bank Detail Page skeleton**
Create `app/(dashboard)/banks/[bankId]/page.tsx` that receives `params.bankId` and renders a new `BankDetailContent` component (to be built next).

- [ ] **Step 3: Commit**
```bash
git add front/financial-app/
git commit -m "refactor(front): remove transactions from sidebar and add bank detail route"
```

---

### Task 4: Refactor Banks Index Page (Pagination & Grid)

**Files:**
- Modify: `front/financial-app/components/pages/banks/BanksContent.tsx`
- Modify: `front/financial-app/components/pages/banks/BankCard.tsx`

- [ ] **Step 1: Update BanksContent**
Implement client-side pagination (6 items per page) for the `banks` array.
Add `<Pagination>` controls at the bottom of the grid.
Adjust the header to match the spec (larger, more left padding).

- [ ] **Step 2: Simplify BankCard**
Remove the expandable accounts list from `BankCard`.
Make the entire card clickable (using `<Link href={"/banks/" + bank.id}>` or `useRouter().push`).
Display the new summary fields: `totalBalances` (using a currency formatter map), `accountsCount`, `cardsCount`, `loansCount`.
Add a notification bell icon to the card if there are unread notifications matching this `bankId` (you will need to use `useNotifications` and filter by metadata).

- [ ] **Step 3: Commit**
```bash
git add front/financial-app/components/pages/banks/
git commit -m "feat(front): redesign banks index with pagination and summaries"
```

---

### Task 5: Build Bank Detail Page & Account Actions

**Files:**
- Create: `front/financial-app/components/pages/banks/BankDetailContent.tsx`
- Modify: `front/financial-app/components/pages/banks/AccountList.tsx` (Extract from old BankCard)

- [ ] **Step 1: Create BankDetailContent**
Fetch the specific bank using `useBanks()`.
Display a large header with the Bank's name and logo.
Render a list of Accounts taking full width.
Add "+ Add account" button at the bottom.

- [ ] **Step 2: Enhance Account Rows**
For each account, display its balance.
Add three prominent action buttons: `Transfer`, `Deposit`, `Withdraw`.
`Transfer` opens the existing `TransferDialog`.
`Deposit` / `Withdraw` should open a simple transaction dialog (pre-filled with the `accountId` and `TransactionType.INCOME` or `EXPENSE`).

- [ ] **Step 3: Commit**
```bash
git add front/financial-app/
git commit -m "feat(front): build bank detail view with account quick actions"
```

---

### Task 6: Redesign Cards & Loans UI

**Files:**
- Modify: `front/financial-app/components/pages/banks/CardList.tsx`
- Modify: `front/financial-app/components/pages/banks/LoanList.tsx`

- [ ] **Step 1: Physical Card UI**
Update `CardList.tsx`. Instead of a white row, render a `div` that looks like a credit card:
- Aspect ratio ~1.58 (standard card).
- Gradient background based on `brand` (e.g., Blue for Visa, Red/Orange for Mastercard, Gray/Black for Amex).
- Prominent white text: `•••• •••• •••• {last4Digits}`.
- Replace the inline buttons with a top-right `DropdownMenu` (three dots) containing: "Add Expense", "View Installments", "Delete".

- [ ] **Step 2: Improve Loan UI**
Update `LoanList.tsx`. Make the expand/pay buttons more prominent with high-contrast colors (e.g., primary color for "Pay" instead of outline). Ensure the expand icon is clearly visible.

- [ ] **Step 3: Commit**
```bash
git add front/financial-app/components/pages/banks/
git commit -m "feat(front): implement physical card UI and improve loan visibility"
```

---

## Definition of Done
- [ ] `BankResponse` includes `totalBalances` and entity counts.
- [ ] "Transactions" is removed from the sidebar.
- [ ] `/banks` shows a paginated grid of summary cards.
- [ ] `/banks/[id]` shows full-width accounts with Transfer/Deposit/Withdraw actions.
- [ ] Credit cards look like physical cards with dropdown actions.
- [ ] All tests passing.
