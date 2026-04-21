# Investments & Bank Integration Final Plan

## Objective
Deeply integrate the Investments module with the Banking system. Investment accounts will become automated summaries of their holdings, and all investment activities (Buy/Sell) will trigger real-time balance adjustments in associated funding accounts within the same bank.

## Architectural Rules
1. **Investment Accounts:** 
   - Balance = Sum of (Holding Quantity * Current Price).
   - Read-only balance (no manual deposits/withdrawals).
   - Only ONE investment account allowed per bank.
   - Cannot be deleted if holdings exist.
2. **Holdings:**
   - Must be linked to a Bank and its single Investment Account.
   - **Buy Flow:** Deducts `qty * price` from a selected non-investment account in the SAME bank.
   - **Sell Flow:** Credits `qty * current_price` to a selected non-investment account in the SAME bank.
3. **Consistency:** All movements trigger `PaymentEvents` for transaction history in `ms-finances`.

## Key Files & Context
- **ms-banks**: `AccountService.java`, `AccountController.java`, `AccountRepository.java`.
- **ms-investments**: `HoldingService.java`, `Holding.java`, `BanksClient.java`.
- **frontend**: `HoldingForm.tsx`, `HoldingTable.tsx`, `BankDetailContent.tsx`.

## Implementation Steps

### Phase 1: ms-banks (Account Integrity)
1. **Validation:** In `AccountService.create`, prevent creating an `INVESTMENT` account if one already exists in the same bank for that user.
2. **Protection:** In `AccountService.delete`, call `ms-investments` to check for holdings before allowing deletion of an `INVESTMENT` account.
3. **Locking:** In `AccountService.adjustBalance`, throw an error if the target account is of type `INVESTMENT`.

### Phase 2: ms-investments (Transaction Logic)
1. **Entity Update:** Ensure `Holding` has `bankId` and `bankAccountId`.
2. **BanksClient:** Create/Update Feign client to call `ms-banks` for balance adjustments.
3. **Buy Logic (`HoldingService.create`):**
   - Calculate total cost.
   - Call `ms-banks.adjustBalance` for the `fundingAccountId`.
   - Emit `PaymentEvent` with description "Investment Buy: [Ticker]".
4. **Sell Logic (New `HoldingService.sell`):**
   - Calculate current value.
   - Call `ms-banks.adjustBalance` for the `destinationAccountId`.
   - Emit `PaymentEvent` with description "Investment Sell: [Ticker]".
   - Delete the holding record.

### Phase 3: Frontend Redesign
1. **HoldingForm:**
   - Mandatory Bank selection.
   - "Funding Account" selector filtered by current bank and type != `INVESTMENT`.
2. **Holding Actions:**
   - Replace "Delete" with a "Sell" button that opens a dialog to select the destination account.
3. **BankDetailContent:**
   - Hide/Disable action buttons (Deposit, Withdraw, Transfer) for accounts of type `INVESTMENT`.

## Verification
- Verify that `INVESTMENT` account balance updates automatically when adding/removing holdings.
- Confirm funds are correctly deducted/added to the chosen Checking/Savings account.
- Verify that a bank cannot have two investment accounts.
- Verify transaction history in the Transactions page.