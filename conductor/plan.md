# Bank-Level Cards and Loans UI Redesign Plan

This plan documents the migration of Cards and Loans from being Account-level entities to Bank-level entities, including a UI redesign for the Bank Details page.

## Objective
Decouple Credit Cards and Loans from specific accounts, allowing them to belong directly to a Bank. Enable users to choose which account to use when paying installments. Redesign the Bank Details page to accommodate this new structure.

## Key Files & Context
- **Frontend (`front/financial-app/`)**:
  - `types/cards.ts`, `types/loans.ts`
  - `lib/api/cards.ts`, `lib/api/loans.ts`
  - `lib/hooks/useCards.ts`, `lib/hooks/useLoans.ts`
  - `components/pages/banks/BankDetailContent.tsx` (Main layout change)
  - `components/pages/banks/CardList.tsx`, `components/pages/banks/CardFormDialog.tsx`
  - `components/pages/banks/CardDetailDialog.tsx` (Add account selector for payment)
  - `components/pages/loans/LoanList.tsx`, `components/pages/loans/LoanForm.tsx`, `components/pages/loans/LoansContent.tsx`
- **Backend (`back/ms-banks/` & `back/ms-finances/`)**:
  - Entities: `Card`, `Loan` (Move `accountId` to `bankId`)
  - Controllers/Services: Update creation and listing logic.
  - Payment Endpoints: Update `payInstallment` endpoints to accept an `accountId` as the funding source for the payment transaction.

## Implementation Steps

### Phase 1: Backend Architecture Changes (ms-banks)
1. **Database & Entities:**
   - Update `Card` entity: Replace `accountId` with `bankId`.
   - Update `Loan` entity: Replace `accountId` with `bankId`.
   - Create/Update Liquibase or Flyway migrations (if used) or update Hibernate schema generation.
2. **DTOs & Controllers:**
   - Update `CardRequest` and `LoanRequest` DTOs to receive `bankId` instead of `accountId`.
   - Update `CardController` and `LoanController` listing endpoints (`GET`) to filter by `bankId`.
3. **Payment Logic:**
   - Update `payInstallment` endpoints for both Cards and Loans to require an `accountId` as a request parameter or body field.
   - The backend must verify that the provided `accountId` belongs to the same user and has sufficient funds (and matches the currency) before recording the payment in `ms-finances`.

### Phase 2: Frontend Data Layer & Types
1. **Types:**
   - Update `Card` and `Loan` interfaces in `types/cards.ts` and `types/loans.ts` to use `bankId`.
   - Update `CardRequest` and `LoanRequest`.
2. **API Clients & Hooks:**
   - Update `cardsApi.list` and `loansApi.list` to accept `bankId`.
   - Update `useCards(bankId)` and `useLoans(bankId)`.
   - Update `markPaid` mutations to accept `accountId` as an argument.

### Phase 3: Bank Details UI Redesign
1. **Layout (`BankDetailContent.tsx`):**
   - **Header:** Remains at the top.
   - **Accounts Section:** Render the list of accounts below the header, spanning the full width. Remove the nested rendering of `CardList` and `LoanList` inside each account card.
   - **Cards & Loans Grid:** Below the accounts, create a CSS grid `grid-cols-1 lg:grid-cols-2 gap-6`.
   - Place `<CardList bankId={bank.id} />` in the left column.
   - Place `<LoanList bankId={bank.id} />` in the right column.

### Phase 4: Payment UI & Account Selection
1. **Select Account Dropdown:**
   - In `CardDetailDialog.tsx` and `LoansContent.tsx`, next to the "Pay" button for installments, add a Shadcn UI `<Select>`.
   - Populate the options with accounts from the current bank (`useBank(bankId)`).
   - **Filter options:** Exclude accounts of type `CASH` or `INVESTMENT`. Only include accounts where `account.currency === installment.currency`.
   - Disable the "Pay" button if no account is selected.
2. **Update Forms:**
   - Update `CardFormDialog.tsx` and `LoanForm.tsx` to receive `bankId` instead of `accountId`.

## Verification & Testing
- Verify that Cards and Loans are displayed side-by-side at the bottom of the Bank Details page on desktop, and stacked on mobile.
- Create a new Card/Loan and ensure it is linked to the Bank.
- Attempt to pay an installment:
  - Verify the account dropdown only shows valid accounts (matching currency, not CASH/INVESTMENT).
  - Verify the "Pay" button is disabled until an account is selected.
  - Verify the payment successfully debits the chosen account and updates the UI.