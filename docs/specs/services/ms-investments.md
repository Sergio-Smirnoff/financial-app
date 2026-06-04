# ms-investments — Investments Service Spec

**Port:** 8086
**Framework:** Spring Boot 3.4.2 (MVC)
**Database schema:** `investments`
**Role:** Holdings CRUD, live IOL price feed, portfolio P&L, notification thresholds, and buy/sell cash-flow integration via ms-finances.

---

## Summary

ms-investments tracks a user's investment portfolio. It stores holdings (what you own and at what cost), fetches live market prices from Invertir Online (IOL), computes unrealised P&L and allocation breakdowns, and checks notification thresholds after each price refresh. Buy/sell operations record a CBU-to-CBU transaction in ms-finances so that the funding account balance is updated correctly — the INVESTMENT account in ms-banks is metadata only and never receives direct balance movements.

---

## Domain Model

### Aggregates and Value Objects

| Class | Type | Key fields |
|---|---|---|
| `Holding` | Aggregate (record) | `HoldingId`, `UserId`, `Cbu accountCbu` (metadata), `Ticker`, `name`, `AssetType`, `HoldingQuantity`, `Money avgPurchasePrice`, `ThresholdConfig`, `NotificationTimestamps` |
| `AssetPrice` | Entity (record) | `AssetPriceId`, `Ticker`, `AssetType`, `lastPrice`, `currency`, `openPrice`, `highPrice`, `lowPrice`, `volume`, `dailyVariation`, `pricedAt`, `updatedAt` |
| `AssetPriceHistory` | Entity (record) | `AssetPriceHistoryId`, `Ticker`, `AssetType`, `lastPrice`, `openPrice`, `highPrice`, `lowPrice`, `volume`, `dailyVariation`, `currency`, `pricedAt` |
| `MarketQuote` | Read model | `ticker`, `lastPrice`, `dailyVariation` — used for market discovery panel |
| `PortfolioSnapshot` | Entity | Daily EOD snapshot of per-currency totals for evolution chart |
| `RefreshJob` | Entity | Tracks in-flight / completed price refresh jobs |
| `ThresholdConfig` | VO | `gainPct`, `lossPct` (both nullable NUMERIC(5,2); must be >= 0) |
| `NotificationTimestamps` | VO | `lastGainNotifiedAt`, `lastLossNotifiedAt` (both nullable) |
| `Ticker` | VO | String symbol, e.g. `GGAL`, `AAPL` |
| `HoldingQuantity` | VO | Positive `BigDecimal` quantity |
| `Money` | VO | `amount` + `java.util.Currency` |
| `Cbu` | VO | 22-digit string — account CBU; `accountCbu` on Holding is **metadata only** (never a money endpoint) |
| `UserId` | VO | `Long` |

### AssetType enum

```
STOCK  BOND  CEDEAR  FCI
```

IOL market mapping: `FCI` → `fci`; everything else → `bCBA`.

---

## ER Diagram

```mermaid
erDiagram
    HOLDINGS {
        bigserial id PK
        bigint user_id
        varchar ticker
        varchar name
        varchar asset_type
        numeric quantity
        numeric avg_purchase_price
        varchar currency
        varchar account_cbu
        numeric notify_gain_threshold_pct
        numeric notify_loss_threshold_pct
        timestamp last_gain_notified_at
        timestamp last_loss_notified_at
        timestamp created_at
        timestamp updated_at
    }

    ASSET_PRICES {
        bigserial id PK
        varchar ticker UK
        varchar asset_type
        numeric last_price
        varchar currency
        numeric open_price
        numeric high_price
        numeric low_price
        numeric volume
        numeric daily_variation
        timestamp priced_at
        timestamp updated_at
    }

    ASSET_PRICE_HISTORY {
        bigserial id PK
        varchar ticker
        varchar asset_type
        numeric last_price
        numeric open_price
        numeric high_price
        numeric low_price
        numeric volume
        numeric daily_variation
        varchar currency
        timestamp priced_at
    }

    MARKET_PANEL_QUOTES {
        bigserial id PK
        varchar symbol
        numeric last_price
        numeric daily_variation
        timestamp updated_at
    }

    PORTFOLIO_SNAPSHOTS {
        bigserial id PK
        bigint user_id
        date snapshot_date
        jsonb totals_by_currency
        timestamp created_at
    }

    REFRESH_JOBS {
        bigserial id PK
        varchar status
        timestamp started_at
        timestamp finished_at
    }

    HOLDINGS ||--o{ ASSET_PRICES : "ticker lookup"
    HOLDINGS ||--o{ ASSET_PRICE_HISTORY : "ticker lookup"
```

---

## Price Feed — IOL Integration

`IolApiClient` authenticates with IOL using OAuth2 password-grant (`/token`). The token is cached in-memory and refreshed 60 seconds before expiry. All calls are protected by Resilience4j `@Retry` + `@CircuitBreaker` (name `iolApi`). On a 401 the client re-authenticates and retries once.

| IOL endpoint used | Purpose |
|---|---|
| `POST /token` | Password-grant auth |
| `GET /api/v2/{market}/Titulos/{ticker}/CotizacionDetalle` | Live OHLC + volume + daily variation for a single ticker |
| `GET /api/v2/{market}/Titulos/{ticker}/Cotizacion/seriehistorica/{from}/{to}/sinAjustar` | Historical series for a ticker (used to backfill price history) |
| `GET /api/v2/Cotizaciones/Acciones/{market}/Argentina` | Panel quotes for market discovery |

Fields extracted: `ultimoPrecio`, `apertura`, `maximo`, `minimo`, `volumen`/`volumenNominal`, `variacion`, `fechaHora`.

---

## Scheduled Price Refresh — Sequence Diagram

```mermaid
sequenceDiagram
    participant SCH as PriceRefreshScheduler<br/>(cron: iol.price-refresh-cron)
    participant RFR as RefreshPricesUseCase
    participant IOL as IolApiClient (IOL API)
    participant APR as AssetPriceRepository
    participant APH as AssetPriceHistoryRepository
    participant THR as EvaluateThresholdsUseCase
    participant KFK as KafkaDomainEventPublisher

    SCH->>RFR: execute()
    RFR->>APR: findAll active tickers
    loop per ticker
        RFR->>IOL: getPrice(ticker, assetType)
        IOL-->>RFR: IolPriceDetail (OHLC + volume + variation)
        RFR->>APR: upsert AssetPrice (last_price, open, high, low, volume, variation)
        RFR->>APH: insert AssetPriceHistory snapshot
    end
    RFR-->>SCH: done
    SCH->>THR: execute()
    THR->>APR: load all prices
    loop per holding with threshold
        THR->>THR: compute plPercent vs ThresholdConfig
        alt gain threshold breached
            THR->>KFK: publish PriceThresholdBreachedEvent (GAIN)
            THR->>HoldingRepository: stamp lastGainNotifiedAt
        else loss threshold breached
            THR->>KFK: publish PriceThresholdBreachedEvent (LOSS)
            THR->>HoldingRepository: stamp lastLossNotifiedAt
        end
    end
```

`@CacheEvict(value = "portfolio", allEntries = true)` runs before the scheduled method so stale portfolio data is flushed.

---

## Additional Schedulers

| Scheduler | Trigger | Use case |
|---|---|---|
| `PriceRefreshScheduler` | `iol.price-refresh-cron` (weekdays 10–17 ARS) | Refresh live prices + evaluate thresholds |
| `MarketDiscoveryScheduler` | Fixed rate `iol.discovery-refresh-rate` (default 15 min) | Sync panel quotes for market discovery |
| `PortfolioSnapshotScheduler` | `0 0 0 * * *` (daily midnight) | Capture per-user portfolio snapshots for evolution chart |

---

## Portfolio Service

`GetPortfolioSummaryUseCase` joins every holding's `Holding` with its current `AssetPrice` to produce:

- **Cost basis** — `quantity × avgPurchasePrice` per currency
- **Current value** — `quantity × lastPrice` per currency
- **Unrealised P&L** — `currentValue − costBasis` per currency
- **P&L %** — `(currentValue − costBasis) / costBasis × 100`
- **Allocation breakdown** — percentage of total value per ticker and per `AssetType`

`GetPortfolioEvolutionUseCase` reads `PortfolioSnapshot` rows for a given user and number of days, returning one `PortfolioEvolutionPoint` (ARS + USD totals) per day for the Recharts evolution chart.

---

## Notification Thresholds

Each `Holding` carries a `ThresholdConfig` (`gainPct`, `lossPct`). After every scheduled price refresh, `EvaluateThresholdsUseCase` computes the current P&L % for every holding that has at least one threshold set (partial index `idx_holdings_notify` makes this efficient).

When a threshold is breached:
1. `KafkaDomainEventPublisher` emits `PriceThresholdBreachedEvent` (topic driven by Kafka config).
2. The corresponding `NotificationTimestamps` field (`lastGainNotifiedAt` / `lastLossNotifiedAt`) is stamped on the `Holding` to prevent re-notification.
3. The frontend `HoldingDetailDialog` reads these timestamps and the current `plPercent` client-side to show breach status.

---

## Bank-Contract Integration (Buy / Sell Cash Flow)

INVESTMENT accounts in ms-banks throw `AccountInvestmentRestrictionException` on any balance movement — they are metadata only. Cash for buys and sells flows exclusively through ms-finances as CBU-to-CBU transactions.

**Buy flow:**

```
fundingCbu (owned) → brokerSentinelCbu(currency) [unowned]
ms-finances persists tx → emits transaction.created (Kafka)
ms-banks debits fundingCbu (sentinel unowned → no credit)
investment account untouched
```

**Sell flow:**

```
brokerSentinelCbu(currency) [unowned] → destinationCbu (owned)
ms-finances persists tx → emits transaction.created (Kafka)
ms-banks credits destinationCbu (sentinel unowned → no debit)
```

`FinancesGatewayImpl` resolves the broker sentinel CBU from `InvestmentsIntegrationProperties` by currency code (env vars `INVEST_BROKER_CBU_ARS`, `INVEST_BROKER_CBU_USD`, etc.). The transaction is recorded before the holding is persisted; a `FinancesServiceException` aborts the entire operation.

```mermaid
sequenceDiagram
    participant FE as Frontend
    participant INV as ms-investments
    participant FIN as ms-finances
    participant KFK as Kafka
    participant BNK as ms-banks

    FE->>INV: POST /api/v1/investments/holdings<br/>{ accountCbu, fundingCbu, ticker, qty, price, currency }
    INV->>INV: Holding.create(accountCbu=metadata)
    INV->>FIN: POST /api/v1/finances/transactions<br/>{ fromCbu=fundingCbu, toCbu=brokerSentinel, amount, currency }
    FIN->>FIN: persist transaction
    FIN-->>INV: 201 TransactionResponse
    INV->>INV: persist Holding
    INV-->>FE: 201 HoldingResponse
    FIN--)KFK: transaction.created
    KFK--)BNK: debit fundingCbu
    Note over BNK: brokerSentinel unowned → no credit<br/>investment account never touched
```

---

## Flyway Migrations

| Version | Description |
|---|---|
| V1 | Init: `holdings`, `asset_prices` tables + basic indexes |
| V2 | Threshold fields: `notify_gain_threshold_pct`, `notify_loss_threshold_pct`, `last_gain_notified_at`, `last_loss_notified_at` on `holdings` |
| V3 | Performance indexes: composite `(user_id, ticker)`, partial `WHERE notify_*_threshold_pct IS NOT NULL`, `asset_prices(ticker)` |
| V4 | OHLC columns on `asset_prices` (open, high, low, volume, daily_variation); creates `asset_price_history` table |
| V5 | Adds `bank_account_id BIGINT` to `holdings` (pre-contract migration, superseded) |
| V6 | Adds `bank_id BIGINT` to `holdings` (pre-contract migration, superseded) |
| V7 | Creates `portfolio_snapshots` table |
| V8 | Creates `market_panel_quotes` table |
| V9 | Adds `volume` and `currency` to `market_panel_quotes` |
| V10 | Creates `refresh_jobs` table |
| V11 | `portfolio_snapshots.totals_by_currency` as JSONB |
| V12 | Bank-contract migration: drops `bank_account_id` + `bank_id`; adds `account_cbu VARCHAR(22)` + index |

---

## API Endpoints

### Holdings — `/api/v1/investments/holdings`

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/v1/investments/holdings` | List user holdings, paginated; optional `?assetType=` filter |
| `GET` | `/api/v1/investments/holdings/valuation?accountCbu=` | Total valuation for holdings linked to a given CBU |
| `GET` | `/api/v1/investments/holdings/count?accountCbu=` | Count of holdings linked to a given CBU |
| `POST` | `/api/v1/investments/holdings` | Create a new holding (records buy transaction in ms-finances if `fundingCbu` provided) |
| `PUT` | `/api/v1/investments/holdings/{id}` | Update holding fields |
| `DELETE` | `/api/v1/investments/holdings/{id}?destinationCbu=` | Close (sell) a holding; records sale proceeds transaction in ms-finances if `destinationCbu` provided |

### Portfolio — `/api/v1/investments/portfolio`

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/v1/investments/portfolio/summary` | Portfolio summary: totals, P&L, allocation breakdown per user |
| `GET` | `/api/v1/investments/portfolio/holdings` | All holdings enriched with current price and P&L |
| `GET` | `/api/v1/investments/portfolio/holdings/{holdingId}` | Single holding detail with current price and P&L |
| `GET` | `/api/v1/investments/portfolio/evolution?days=` | Historical portfolio evolution (ARS + USD) for N days |

### Prices — `/api/v1/investments/prices`

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/api/v1/investments/prices/refresh` | Manually trigger a full price refresh for all held tickers |

### Price History — `/api/v1/investments/prices/history`

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/v1/investments/prices/history/{ticker}?from=&to=` | OHLC price history for a ticker (ISO datetime params; omit both for all history — defaults to 10-year look-back) |

### Market Discovery — `/api/v1/investments/market`

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/v1/investments/market/discovery?limit=` | Trending assets not already in the user's portfolio (default limit 5) |

All endpoints return `ApiResponse<T>` (`success`, `message`, `data`, `errors`, `timestamp`). Numeric response fields are serialised as `String` to avoid JSON precision loss.

---

## Source Tree

```
back/ms-investments/src/main/java/com/financialapp/investments/
├── InvestmentsApplication.java
├── domain/
│   ├── common/
│   │   ├── DomainEvent.java
│   │   └── model/
│   │       ├── Cbu.java
│   │       ├── Money.java
│   │       ├── PageRequest.java
│   │       ├── PageResult.java
│   │       └── UserId.java
│   ├── event/
│   │   ├── Direction.java
│   │   ├── HoldingClosedEvent.java
│   │   ├── HoldingCreatedEvent.java
│   │   ├── HoldingUpdatedEvent.java
│   │   └── PriceThresholdBreachedEvent.java
│   ├── exception/
│   │   ├── DomainError.java
│   │   ├── DomainException.java
│   │   ├── FinancesServiceException.java
│   │   ├── IolServiceException.java
│   │   ├── ResourceAlreadyExistsException.java
│   │   ├── ResourceConflictException.java
│   │   ├── ResourceNotFoundException.java
│   │   ├── UnsupportedCurrencyException.java
│   │   └── holding/
│   │       ├── HoldingCurrencyMismatchException.java
│   │       └── HoldingQuantityNonPositiveException.java
│   ├── gateway/
│   │   ├── DomainEventPublisher.java
│   │   ├── FinancesGateway.java          ← port: recordPurchase / recordSaleProceeds
│   │   ├── HoldingQueryGateway.java
│   │   ├── IolGateway.java
│   │   └── SupportedCurrencies.java
│   ├── model/
│   │   ├── history/
│   │   │   ├── AssetPriceHistory.java
│   │   │   ├── AssetPriceHistoryId.java
│   │   │   └── HistoricalPricePoint.java
│   │   ├── holding/
│   │   │   ├── Holding.java
│   │   │   ├── HoldingFilter.java
│   │   │   ├── HoldingId.java
│   │   │   ├── HoldingQuantity.java
│   │   │   ├── NotificationTimestamps.java
│   │   │   ├── ThresholdConfig.java
│   │   │   └── Ticker.java
│   │   ├── market/
│   │   │   └── MarketQuote.java
│   │   ├── price/
│   │   │   ├── AssetPrice.java
│   │   │   ├── AssetPriceId.java
│   │   │   ├── AssetType.java
│   │   │   └── PriceDetail.java
│   │   ├── refresh/
│   │   │   ├── RefreshJob.java
│   │   │   ├── RefreshJobId.java
│   │   │   └── RefreshJobStatus.java
│   │   └── snapshot/
│   │       ├── PortfolioSnapshot.java
│   │       └── PortfolioSnapshotId.java
│   ├── repository/
│   │   ├── AssetPriceHistoryRepository.java
│   │   ├── AssetPriceRepository.java
│   │   ├── HoldingRepository.java
│   │   ├── MarketQuoteRepository.java
│   │   ├── PortfolioSnapshotRepository.java
│   │   └── RefreshJobRepository.java
│   └── usecase/
│       ├── holding/
│       │   ├── CloseHoldingUseCase.java
│       │   ├── CreateHoldingUseCase.java
│       │   ├── GetAccountValuationUseCase.java
│       │   ├── GetHoldingDetailUseCase.java
│       │   ├── ListHoldingsUseCase.java
│       │   ├── UpdateHoldingUseCase.java
│       │   ├── command/  (CloseHoldingCommand, CreateHoldingCommand, …)
│       │   └── response/ (AccountValuationResult)
│       ├── market/
│       │   ├── GetMarketDiscoveryUseCase.java
│       │   ├── SyncMarketQuotesUseCase.java
│       │   ├── command/ (GetMarketDiscoveryCommand)
│       │   └── response/ (MarketOpportunityResult)
│       ├── portfolio/
│       │   ├── GetHoldingsWithPricesUseCase.java
│       │   ├── GetPortfolioEvolutionUseCase.java
│       │   ├── GetPortfolioSummaryUseCase.java
│       │   ├── command/  (GetHoldingsWithPricesCommand, …)
│       │   └── response/ (AllocationBreakdownResult, HoldingWithPriceResult, PortfolioSummaryResult, …)
│       ├── price/
│       │   ├── EvaluateThresholdsUseCase.java
│       │   ├── GetPriceHistoryUseCase.java
│       │   ├── RefreshPricesUseCase.java
│       │   └── command/ (GetPriceHistoryCommand)
│       └── snapshot/
│           └── CapturePortfolioSnapshotUseCase.java
├── application/
│   ├── holding/impl/  (CloseHoldingUseCaseImpl, CreateHoldingUseCaseImpl, …)
│   ├── market/impl/   (GetMarketDiscoveryUseCaseImpl, SyncMarketQuotesUseCaseImpl)
│   ├── portfolio/impl/ (GetHoldingsWithPricesUseCaseImpl, GetPortfolioEvolutionUseCaseImpl, GetPortfolioSummaryUseCaseImpl)
│   ├── price/impl/    (EvaluateThresholdsUseCaseImpl, GetPriceHistoryUseCaseImpl, RefreshPricesUseCaseImpl)
│   └── snapshot/impl/ (CapturePortfolioSnapshotUseCaseImpl)
├── infrastructure/
│   ├── config/
│   │   ├── CacheConfig.java
│   │   ├── CurrenciesProperties.java
│   │   ├── FeignConfig.java
│   │   ├── InternalAuthFilter.java
│   │   ├── InvestmentsIntegrationProperties.java   ← brokerCbuFor(currency), financesCategoryId
│   │   ├── IolProperties.java
│   │   ├── KafkaConfig.java
│   │   └── SupportedCurrenciesImpl.java
│   ├── gateway/
│   │   ├── IolApiClient.java                       ← OAuth2 token cache, CotizacionDetalle, seriehistorica, panel
│   │   ├── FinancesClient.java                     ← Feign to ms-finances
│   │   ├── dto/  (FinancesApiResponse, IolHistoricalPricePoint, IolMarketQuote, IolPriceDetail, RecordTransactionRequest)
│   │   └── impl/ (FinancesGatewayImpl, IolGatewayImpl)
│   ├── messaging/
│   │   ├── KafkaDomainEventPublisher.java
│   │   ├── TransactionalKafkaEvent.java
│   │   ├── TransactionalKafkaListener.java
│   │   └── mapper/  (InvestmentKafkaMapper)
│   │   └── payload/ (InvestmentThresholdPayload)
│   ├── persistence/
│   │   ├── entity/  (AssetPriceHistoryJpaEntity, AssetPriceJpaEntity, HoldingJpaEntity, MarketPanelQuoteJpaEntity, PortfolioSnapshotJpaEntity, RefreshJobJpaEntity)
│   │   ├── jpa/     (Spring Data repositories)
│   │   ├── mapper/  (MapStruct persistence mappers)
│   │   └── repository/ (domain repository impls)
│   └── scheduler/
│       ├── MarketDiscoveryScheduler.java
│       ├── PortfolioSnapshotScheduler.java
│       └── PriceRefreshScheduler.java
└── web/
    ├── controller/
    │   ├── HoldingController.java
    │   ├── MarketDiscoveryController.java
    │   ├── PortfolioController.java
    │   ├── PriceController.java
    │   └── PriceHistoryController.java
    ├── dto/
    │   ├── request/  (HoldingRequest, SupportedCurrency, SupportedCurrencyValidator)
    │   └── response/ (AccountValuationResponse, AllocationBreakdown, ApiResponse, HoldingDetailResponse, HoldingResponse, HoldingWithPriceResponse, MarketDiscoveryResponse, PortfolioEvolutionResponse, PortfolioSummaryResponse, PriceHistoryResponse, …)
    ├── error/
    │   └── GlobalExceptionHandler.java
    └── mapper/
        ├── HoldingWebMapper.java
        ├── MarketWebMapper.java
        ├── PortfolioWebMapper.java
        └── PriceWebMapper.java
```

---

## Key Configuration (env vars)

| Env var | Purpose |
|---|---|
| `IOL_BASE_URL` | IOL API base URL |
| `IOL_USERNAME` / `IOL_PASSWORD` | IOL OAuth2 credentials |
| `IOL_PRICE_REFRESH_CRON` | Cron expression for `PriceRefreshScheduler` |
| `IOL_DISCOVERY_REFRESH_RATE` | Fixed-rate ms for `MarketDiscoveryScheduler` (default 900000) |
| `INVEST_BROKER_CBU_ARS` | Sentinel CBU for ARS buy/sell counter-party |
| `INVEST_BROKER_CBU_USD` | Sentinel CBU for USD buy/sell counter-party |
| `INVEST_FINANCES_CATEGORY_ID` | Fixed id of the "Investments" system category in ms-finances |
| `SPRING_DATASOURCE_URL` | PostgreSQL connection (schema `investments`) |
| `KAFKA_BOOTSTRAP_SERVERS` | Kafka brokers (`localhost:9093` for local dev) |

---

## Related Specs

- [Master](../00-master.md)
- [Architecture](../architecture.md)
- [Rules](../rules.md)
- [Workflow](../workflow.md)
- [Bank-contract migration design](../../superpowers/archive/specs/2026-06-02-ms-investments-bank-contract-migration-design.md)
