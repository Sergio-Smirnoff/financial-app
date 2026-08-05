# External Contracts

Third-party systems no single service owns. Service-specific call sites live in that repo's
`.ai/references/EVENTS.md`.

## IOL / broker API

- Base URL: `IOL_BASE_URL` (default `https://api.invertironline.com`).
- Auth: OAuth2 password grant against `POST {base}/token`; bearer token cached in memory,
  refreshed ~60s before `expires_in` elapses. Credentials: `IOL_USERNAME`, `IOL_PASSWORD`.
- Endpoints called: `GET /api/v2/{market}/Titulos/{ticker}/CotizacionDetalle` (live quote),
  `GET /api/v2/{market}/Titulos/{ticker}/Cotizacion/seriehistorica/{from}/{to}/sinAjustar`
  (historical series), `GET /api/v2/Cotizaciones/Acciones/{market}/Argentina` (market list).
- Rate limits: none enforced client-side today; a resilience4j circuit breaker wraps calls
  (`failure-rate-threshold: 50`) but there is no throttle. Check IOL's published limits before
  raising polling frequency.
- Calling repo: `ms-investments` (`IolApiClient`, `IolGatewayImpl`). Price refresh schedule:
  `IOL_PRICE_REFRESH_CRON`.

## BCRA / CBU

- 22 digits in two fixed blocks: bank number (3) + sucursal code (4) + check digit 1 (1) = 8;
  account number (13) + check digit 2 (1) = 14.
- Both check digits are BCRA modulo-10 with fixed weight vectors — first block
  `7 1 3 9 7 1 3`, second block `3 9 7 1 3 9 7 1 3 9 7 1 3`.
- `BankNumber` is the leading 3-digit entity code.
- Current state: **no shared `Cbu` in commons.** `ms-banks`, `ms-finances`, `ms-investments`
  and `ms-upload` each carry their own `Cbu` domain type, and the implementations have
  drifted (`ms-banks` decomposes into parts plus both check digits; `ms-finances` validates
  only the raw 22-digit string). This is an open R4 violation — do not add a fifth copy; if
  you touch CBU validation, consolidate into commons instead of re-implementing again.

## SMTP

- Env vars: `MAIL_HOST`, `MAIL_PORT`, `MAIL_USERNAME`, `MAIL_PASSWORD`.
- TLS: STARTTLS (`mail.smtp.starttls.enable=true`), SMTP AUTH on.
- Calling repo: `ms-notifications`.
- Templates: `ms-notifications/src/main/resources/templates/email/*.html` — welcome,
  payment-due, loan-reminder, installment-reminder, investment-threshold, monthly-summary.

## MinIO

- Env vars: `MINIO_ENDPOINT`, `MINIO_ACCESS_KEY`, `MINIO_SECRET_KEY`,
  `MINIO_BUCKET_STATEMENTS`, `MINIO_BUCKET_RECEIPTS`.
- Path convention: `temp/<uuid>/<original-filename>` for in-flight uploads, before an import
  run promotes or discards the object.
- Calling repo: `ms-upload` (`StatementStoragePortImpl`, `MinioStorageService`).

## FX rate sources

- Provider: IOL, via bond-pair implied pricing — no dedicated FX endpoint; pairs configured in
  `FxPairsProperties`.
- Today's rate is fetched live on demand; historical rates are persisted to `FxRateJpaEntity`
  and read back from `FxRateRepository`, not re-fetched.
- Owning repo / read model: `ms-investments` (`FxLegPriceGatewayImpl`,
  `GetFxRatesAtDateUseCaseImpl`).
