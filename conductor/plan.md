# Account Filters Implementation Plan

## Background & Motivation
The user currently has multiple accounts within a bank, making it difficult to find specific ones (e.g., finding only USD accounts, hiding unused/empty accounts, or filtering by type such as SAVINGS).

## Objective
Implement a filtering toolbar in the Bank Details page (`BankDetailContent.tsx`) above the accounts list. The toolbar will allow users to filter accounts by name, currency, type, and balance status.

## Key Files & Context
- `front/financial-app/components/pages/banks/BankDetailContent.tsx`

## Scope & Impact
This is a purely frontend change. It affects only the rendering logic of the accounts array in `BankDetailContent.tsx`. No backend API changes or database migrations are required.

## Proposed Solution

1. **State Management:**
   - Add state variables in `BankDetailContent.tsx`:
     - `searchQuery` (string, default: '')
     - `filterCurrency` (string, default: 'ALL')
     - `filterType` (string, default: 'ALL')
     - `hideEmptyAccounts` (boolean, default: false)

2. **Filtering Logic:**
   - Use `useMemo` to derive a `filteredAccounts` array from `bank.accounts`.
   - Apply filters sequentially:
     - *Name:* Match `searchQuery` case-insensitively against `account.name`.
     - *Currency:* Match `filterCurrency` against `account.currency` (if not 'ALL').
     - *Type:* Match `filterType` against `account.type` (if not 'ALL').
     - *Empty Accounts:* If `hideEmptyAccounts` is true, exclude accounts where `account.balance === 0`.

3. **UI Components (Toolbar):**
   - Above the `<section className="space-y-4">` for Accounts, add a new `<div className="flex flex-wrap gap-4 items-center">`.
   - Use Shadcn UI components:
     - `<Input>` for the search bar (with a magnifying glass icon placeholder).
     - `<Select>` for Currency (e.g., ALL, USD, ARS). Determine options dynamically from the available accounts or statically if preferred (ARS, USD, EUR).
     - `<Select>` for Type (e.g., ALL, CHECKING, SAVINGS, INVESTMENT, CASH).
     - `<div className="flex items-center space-x-2">` containing a `<Switch>` for "Hide empty accounts".
     - A `<Button variant="ghost">` or icon to reset all filters.

4. **Rendering:**
   - Update the mapping from `bank.accounts.map` to `filteredAccounts.map`.
   - Show a fallback message (e.g., "No accounts match your filters") if `filteredAccounts.length === 0` but `bank.accounts.length > 0`.

## Implementation Steps

1. Import required components (`Input`, `Select`, `Switch`, `Label`) from `@/components/ui/...` into `BankDetailContent.tsx`.
2. Add the filtering state variables.
3. Implement the `useMemo` block to compute `filteredAccounts`.
4. Extract unique currencies and types from `bank.accounts` to populate the Select options dynamically, ensuring the dropdowns only show relevant options for that specific bank.
5. Build the UI toolbar directly above the accounts grid.
6. Replace `bank.accounts.map` with `filteredAccounts.map`.
7. Add the "No matches" fallback state.

## Verification & Testing
- Load a bank with multiple accounts of different currencies, types, and balances.
- Type in the search bar and verify only matching names appear.
- Select 'USD' from the currency filter and verify 'ARS' accounts disappear.
- Toggle 'Hide empty accounts' and verify accounts with a balance of `0` disappear.
- Click 'Clear Filters' and verify the original list is restored.