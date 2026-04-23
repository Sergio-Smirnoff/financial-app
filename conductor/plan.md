# Investments Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the reversed transaction signs in `ms-investments` that corrupt the finances history, and add missing `bankId` and `bankAccountId` fields to `HoldingWithPriceResponse` to fix frontend editing and selling bugs.

**Architecture:** 
1. Update `HoldingService` in `ms-investments` to reverse the signs of `amount` in all `PaymentEvent` emissions. Funding accounts should send negative amounts (expenses), and investment accounts should send positive amounts (income) when buying. The reverse applies when selling.
2. Update `HoldingWithPriceResponse` in `ms-investments` to include `bankId` and `bankAccountId`.
3. Update `PortfolioService` in `ms-investments` to populate these new fields when building the `HoldingWithPriceResponse`.

**Tech Stack:** Java, Spring Boot, Kafka

---

### Task 1: Fix Transaction Signs in HoldingService

**Files:**
- Modify: `back/ms-investments/src/main/java/com/financialapp/investments/service/HoldingService.java`

- [ ] **Step 1: Fix signs in `create` method (Buy)**
Update `HoldingService.java` around line 60-80 to reverse the `amount` logic in the `PaymentEvent` builders. Funding accounts should be expenses (negative), and investment accounts should be income (positive).
```java
            // Record transaction in funding account (Debit/Expense)
            eventProducer.publishPayment(PaymentEvent.builder()
                    .userId(userId)
                    .accountId(request.getFundingAccountId())
                    .amount(totalCost.negate()) // FIXED: Now negative
                    .currency(request.getCurrency())
                    .description("Investment Buy: " + request.getTicker())
                    .date(LocalDate.now())
                    .build());

            // Record transaction in investment account (Credit/Income)
            eventProducer.publishPayment(PaymentEvent.builder()
                    .userId(userId)
                    .accountId(request.getBankAccountId())
                    .amount(totalCost) // FIXED: Now positive
                    .currency(request.getCurrency())
                    .description("Investment Buy: " + request.getTicker())
                    .date(LocalDate.now())
                    .build());
```

- [ ] **Step 2: Fix signs in `update` method**
Update `HoldingService.java` around line 114-132 to reverse the `amount` logic in the `PaymentEvent` builders based on `costDiff`.
```java
            // Record transaction in funding account
            eventProducer.publishPayment(PaymentEvent.builder()
                    .userId(userId)
                    .accountId(request.getFundingAccountId())
                    .amount(costDiff.negate()) // FIXED: Now negated
                    .currency(request.getCurrency())
                    .description("Investment Update (" + (costDiff.signum() > 0 ? "Buy" : "Sell") + "): " + holding.getTicker())
                    .date(LocalDate.now())
                    .build());

            // Record transaction in investment account (inverse of funding)
            eventProducer.publishPayment(PaymentEvent.builder()
                    .userId(userId)
                    .accountId(request.getBankAccountId())
                    .amount(costDiff) // FIXED: Now positive if costDiff is positive
                    .currency(request.getCurrency())
                    .description("Investment Update (" + (costDiff.signum() > 0 ? "Buy" : "Sell") + "): " + holding.getTicker())
                    .date(LocalDate.now())
                    .build());
```

- [ ] **Step 3: Fix signs in `delete` method (Sell)**
Update `HoldingService.java` around line 188-206 to reverse the `amount` logic in the `PaymentEvent` builders. Destination accounts should receive income (positive), and investment accounts should record an expense (negative).
```java
            // Record transaction in destination account (Credit/Income)
            eventProducer.publishPayment(PaymentEvent.builder()
                    .userId(userId)
                    .accountId(destinationAccountId)
                    .amount(liquidationValue) // FIXED: Now positive
                    .currency(holding.getCurrency())
                    .description("Investment Sell: " + holding.getTicker())
                    .date(LocalDate.now())
                    .build());

            // Record transaction in investment account (Debit/Expense)
            eventProducer.publishPayment(PaymentEvent.builder()
                    .userId(userId)
                    .accountId(holding.getBankAccountId())
                    .amount(liquidationValue.negate()) // FIXED: Now negative
                    .currency(holding.getCurrency())
                    .description("Investment Sell: " + holding.getTicker())
                    .date(LocalDate.now())
                    .build());
```

- [ ] **Step 4: Build and test**
Run the Maven build to ensure no syntax errors.
Run: `cd back/ms-investments && mvn clean compile`
Expected: BUILD SUCCESS

---

### Task 2: Add Bank fields to HoldingWithPriceResponse

**Files:**
- Modify: `back/ms-investments/src/main/java/com/financialapp/investments/model/dto/response/HoldingWithPriceResponse.java`
- Modify: `back/ms-investments/src/main/java/com/financialapp/investments/service/PortfolioService.java`

- [ ] **Step 1: Update DTO**
Add `bankId` and `bankAccountId` to `HoldingWithPriceResponse.java`.
```java
package com.financialapp.investments.model.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class HoldingWithPriceResponse {
    private Long id;
    private Long userId;
    private Long bankId; // NEW
    private Long bankAccountId; // NEW
    private String ticker;
    private String name;
    private String assetType;
    private BigDecimal quantity;
    private BigDecimal avgPurchasePrice;
    private String currency;
    private BigDecimal notifyGainThresholdPct;
    private BigDecimal notifyLossThresholdPct;
    private LocalDateTime lastGainNotifiedAt;
    private LocalDateTime lastLossNotifiedAt;
    private BigDecimal currentPrice;
    private BigDecimal currentValue;
    private BigDecimal plAmount;
    private BigDecimal plPercent;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
```

- [ ] **Step 2: Update PortfolioService**
In `PortfolioService.java`, around line 56, add the missing fields to the builder.
```java
            return HoldingWithPriceResponse.builder()
                    .id(h.getId())
                    .userId(h.getUserId())
                    .bankId(h.getBankId()) // NEW
                    .bankAccountId(h.getBankAccountId()) // NEW
                    .ticker(h.getTicker())
                    .name(h.getName())
                    .assetType(h.getAssetType().name())
                    .quantity(h.getQuantity())
                    .avgPurchasePrice(h.getAvgPurchasePrice())
                    .currency(h.getCurrency())
                    .notifyGainThresholdPct(h.getNotifyGainThresholdPct())
                    .notifyLossThresholdPct(h.getNotifyLossThresholdPct())
                    .lastGainNotifiedAt(h.getLastGainNotifiedAt())
                    .lastLossNotifiedAt(h.getLastLossNotifiedAt())
                    .currentPrice(currentPrice)
                    .currentValue(currentValue)
                    .plAmount(plAmount)
                    .plPercent(plPercent)
                    .createdAt(h.getCreatedAt())
                    .updatedAt(h.getUpdatedAt())
                    .build();
```

- [ ] **Step 3: Build and test**
Run the Maven build to ensure no syntax errors.
Run: `cd back/ms-investments && mvn clean compile`
Expected: BUILD SUCCESS

---

### Task 3: Commit the changes

- [ ] **Step 1: Commit backend fixes**
Run: `git add back/ms-investments/src/main/java/com/financialapp/investments/service/HoldingService.java back/ms-investments/src/main/java/com/financialapp/investments/model/dto/response/HoldingWithPriceResponse.java back/ms-investments/src/main/java/com/financialapp/investments/service/PortfolioService.java`
Run: `git commit -m "fix(investments): correct transaction signs and add missing bank fields to portfolio holdings"`
