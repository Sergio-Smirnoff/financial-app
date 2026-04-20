# Bug Fix Implementation Plan

This plan addresses the bugs reported in `docs/notes.txt`.

## Objective
Fix 6 UI/UX bugs in the frontend application to improve user experience and error handling.

## Key Files & Context
- `front/financial-app/lib/hooks/useLoans.ts` (Installment updates)
- `front/financial-app/lib/hooks/useBanks.ts` (Bank/Account mutations)
- `front/financial-app/components/pages/banks/BankDetailContent.tsx` (Account list, UI buttons, Bank notifications)
- `front/financial-app/components/pages/banks/QuickTransactionDialog.tsx` (Deposit/Withdraw categories)

## Implementation Steps

1. **Fix Installments payment not debiting instantly:**
   - In `front/financial-app/lib/hooks/useLoans.ts`, locate `usePayLoanInstallment`.
   - Update the `onSuccess` callback to include `queryClient.invalidateQueries({ queryKey: ['banks'] })` so the account balance updates instantly.

2. **Add UI Error when deleting a bank fails:**
   - In `front/financial-app/lib/hooks/useBanks.ts`, locate `deleteBankMutation`.
   - Add an `onError` handler that uses `toast.error(error.message || 'Failed to delete bank')` to display the `ApiError` to the user.

3. **Add Option to delete accounts:**
   - In `front/financial-app/components/pages/banks/BankDetailContent.tsx`, locate the account card rendering map (`bank.accounts.map(...)`).
   - Add a Delete button (Trash2 icon) next to the History button.
   - Wire it to an `openConfirmDelete` dialog from `useUiStore`, and call `deleteAccount` from `useAccounts` upon confirmation.

4. **Fix Deposit/Withdraw categories dropdown:**
   - Investigate `QuickTransactionDialog.tsx` to ensure the category dropdown correctly fetches and displays the application's actual categories (income/expense) instead of hardcoded or incorrect values. Ensure the mapping from `categories` to `flatSubcategories` works correctly and is bound to the form correctly.

5. **Fix Bank notification bell:**
   - In `BankDetailContent.tsx`, locate the non-interactive bell icon for the specific bank.
   - Wrap it in a `DropdownMenu` or `Dialog` (similar to the global `NotificationBell.tsx`) that displays a filtered list of `useLatestNotifications()` where `metadata.bankId === bankId`.

6. **Remove top "Add Account" button:**
   - In `BankDetailContent.tsx`, locate the top `<Button onClick={handleAddAccount}>` and remove it, leaving only the "Add another account" dashed button at the bottom of the account list.

## Verification & Testing
- Pay an installment and verify the associated bank account balance updates instantly without reloading.
- Attempt to delete a bank with a non-zero balance and verify a red error toast appears with the correct message.
- Delete an account and verify it disappears from the list.
- Open a Deposit/Withdraw dialog and verify the categories dropdown shows the correct app categories.
- Click the notification bell on a bank page and verify it shows the correct bank-specific notifications.
- Verify the top "Add Account" button is gone.