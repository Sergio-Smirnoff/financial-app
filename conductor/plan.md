# Cards UI/UX Improvement Plan

This plan addresses the current issues with the credit cards UI as requested by the user.

## Objective
Improve the visualization of card installments by grouping them into "purchases", update the card actions menu, and provide a comprehensive card details popup.

## Key Files & Context
- `front/financial-app/components/pages/banks/CardList.tsx`
- `front/financial-app/components/pages/banks/CardFormDialog.tsx`
- `front/financial-app/components/pages/banks/CardDetailDialog.tsx` (New/Renamed from CardInstallmentsDialog)
- `front/financial-app/lib/hooks/useCards.ts`
- `front/financial-app/lib/api/cards.ts`

## Implementation Steps

### Task 1: Update Card APIs & Hooks
1. In `cards.ts` API client, add an `update` method for cards.
2. In `useCards.ts`, add a `useUpdateCard` mutation.
3. In `useCards.ts`, update `useDeleteCard` to include an `onError` handler that displays a toast message if the API rejects the deletion (e.g., because there are pending installments).

### Task 2: Refactor CardList Component
1. In `CardList.tsx`, update the 3-dots DropdownMenu to only contain **Edit Card** and **Delete Card**.
2. Add a new state `editingCard: Card | null` and pass it to `CardFormDialog`.
3. Update the main card container `div` to be clickable (`onClick`), opening the new `CardDetailDialog` for the selected card.

### Task 3: Support Card Editing
1. In `CardFormDialog.tsx`, add an `editCard?: Card | null` prop.
2. Pre-fill the form with `editCard` data if provided (using `useEffect` to reset the form when `editCard` changes).
3. On submit, conditionally call the update mutation if editing, or the create mutation if creating a new card.

### Task 4: Create CardDetailDialog (Replaces CardInstallmentsDialog)
1. Create or rename to `CardDetailDialog.tsx`.
2. Fetch installments using `useCardInstallments(cardId)`.
3. **Basic Info Header:** Display card brand, last 4 digits, and behavior. Add an "Add Expense" button to this header or a toolbar.
4. **Group Purchases:** Group the fetched installments by `description`, `totalAmount`, `currency`, and `totalInstallments`. Render an accordion list for these purchases.
5. **Installments per Purchase:** Inside each accordion item, display the installments specific to that purchase, keeping the current functionality (info, "Mark paid" button).
6. **Upcoming Expirations:** At the bottom of the dialog, filter the installments to find those with `dueDate` in less than 3 days and `!paid`. Display them in a separate "Próximos Vencimientos" section.

## Verification & Testing
- Ensure the 3-dots menu only shows Edit/Delete.
- Verify attempting to delete a card with pending installments shows a clear error toast.
- Verify editing a card successfully updates its information.
- Verify clicking a card opens the new details popup.
- Confirm installments are correctly grouped by their corresponding purchase details.
- Confirm "Próximos Vencimientos" accurately filters and displays installments due within 3 days.