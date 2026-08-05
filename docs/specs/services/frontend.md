# Frontend — Next.js App

> Human-facing. Facts an implementer needs live in `front/financial-app/.ai/` — this page holds the
> reasoning behind them and does not restate them. If the two disagree, the repo file wins.

---

## Routing and Layouts

```mermaid
graph TD
    ROOT["app/layout.tsx\n(ThemeProvider · QueryProvider · Toaster)"]

    ROOT --> AUTH["(auth)/layout.tsx\ncentered · no sidebar"]
    ROOT --> DASH["(dashboard)/layout.tsx\nNotificationProvider\nSidebar · MobileSidebar"]

    AUTH --> LOGIN["/login"]
    AUTH --> REGISTER["/register"]

    DASH --> HOME["/ (Dashboard)"]
    DASH --> BANKS["/banks\nAccounts · Cards · Loans tabs"]
    DASH --> TXN["/transactions"]
    DASH --> CAT["/categories"]
    DASH --> LOANS["/loans"]
    DASH --> INV["/investments"]
    DASH --> IMPORTS["/imports"]
    DASH --> SETTINGS["/settings"]
```

### Dashboard layout detail

The `(dashboard)/layout.tsx` renders a fixed-height flex row:

```
┌──────────────────────────────────────────────┐
│  Sidebar (fixed, 240 px, desktop)            │
│  MobileSidebar (drawer, mobile)              │
│ ┌────────────────────────────────────────┐   │
│ │  Header: page title · theme · bell ·  │   │
│ │          user name · logout           │   │
│ ├────────────────────────────────────────┤   │
│ │  <page content>                        │   │
│ └────────────────────────────────────────┘   │
└──────────────────────────────────────────────┘
```

NotificationProvider wraps the entire dashboard tree and mounts the SSE connection via `useNotificationSSE`.

---

## apiFetch 401 → refresh → retry

```mermaid
sequenceDiagram
    participant C as Component
    participant F as apiFetch
    participant R as refreshToken()
    participant G as Gateway

    C->>F: api.get("/some/resource")
    F->>G: GET /some/resource (access_token cookie)
    G-->>F: 401 Unauthorized

    alt refreshing already in-flight
        F->>F: await existing refreshing promise
    else no refresh in-flight
        F->>R: refreshToken() [sets refreshing mutex]
        R->>G: POST /api/v1/users/auth/refresh (refresh_token cookie)
        G-->>R: 200 OK (new access_token cookie set)
        R-->>F: true
        F->>F: refreshing = null
    end

    alt refresh succeeded
        F->>G: GET /some/resource (new access_token cookie)
        G-->>F: 200 OK
        F-->>C: body.data
    else refresh failed
        F->>F: window.location.href = '/login'
        F-->>C: throws ApiError("Session expired", 401)
    end
```

The `refreshing` variable is a module-level `Promise<boolean> | null`. Concurrent 401 responses from parallel requests all `await` the same promise, so exactly one refresh call is ever in-flight.

---

## Recent UX Fixes (2026-06-12)

| Area | Fix |
|---|---|
| Investments — Markets tab | Ticker research now renders inline below `TickerSearchBox` via an `onSelect` callback; the dedicated `/investments/research/[ticker]` route was removed. |
| Transactions table | Sentinel CBUs render labelled operation names: `Brokerage` for broker sentinel CBUs and `External` for the `0000000000000000000000` installment sentinel; user CBUs render raw as before. |
| `PriceChart` | Non-positive price points are filtered out before rendering, eliminating the drop-to-zero spike caused by pre-open / no-trade IOL candles. |
| Card list | Card item layout fixed so the Expires / behavior row is no longer clipped. |
| Notifications dialog | Close button repositioned so it no longer overlaps the "Mark all as read" control. |
