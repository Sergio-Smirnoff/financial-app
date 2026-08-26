#!/usr/bin/env bash
# Seeds a deterministic demo user so every BFF section returns non-empty data.
# Idempotent: running it twice changes nothing.
set -euo pipefail

GW="${GATEWAY_URL:-http://localhost:8080}"
JAR=/tmp/demo-cookies.txt
EMAIL=demo@financial.app
PASSWORD='Demo!2026pass'

CHECKING=0170099200000000000017
SAVINGS=0170099200000000000024
# Not owned by the demo user: spends must leave the wallet or the ownership-derived
# kind classifies them as internal transfers and budgets never see them.
EXTERNAL=2850590940090418135201
CARD=4509953566233704
BANK=017

say() { printf '  %s\n' "$*"; }

# POST that tolerates "already exists" — the idempotency primitive.
post() { # post <path> <json>
  local code
  code=$(curl -s -o /tmp/post.out -w '%{http_code}' -b "$JAR" -c "$JAR" \
    -H 'Content-Type: application/json' -X POST "$GW$1" -d "$2")
  case "$code" in
    200|201) return 0 ;;
    409)     say "exists, skipping: $1" ; return 0 ;;
    *)       echo "POST $1 failed ($code): $(cat /tmp/post.out)" >&2 ; return 1 ;;
  esac
}

# Read a count through the BFF, retrying while the stack is still warming up:
# a cold gateway serves UNAVAILABLE sections whose fallback looks like real emptiness.
bff_count() { # bff_count <url-path> <jq-count-expr>
  local count attempt
  for attempt in 1 2 3 4 5; do
    count=$(curl -s -b "$JAR" "$GW$1" | jq -r "$2" 2>/dev/null || echo 0)
    if [ "${count:-0}" -gt 0 ] 2>/dev/null; then echo "$count"; return 0; fi
    sleep 3
  done
  echo "${count:-0}"
}

# A seed step that persists nothing is a failure, not a success message.
verify() { # verify <label> <url-path> <jq-count-expr>
  local count
  count=$(bff_count "$2" "$3")
  if [ "${count:-0}" -gt 0 ] 2>/dev/null; then
    say "verified: $1 ($count)"
  else
    echo "SEED FAILURE: $1 produced no rows (checked $2)" >&2
    exit 1
  fi
}

# 1. Register & Login
curl -s -o /dev/null -c "$JAR" -H 'Content-Type: application/json' \
  -X POST "$GW/api/v1/auth/register" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\",\"firstName\":\"Demo\",\"lastName\":\"Usuario\"}" || true

curl -sf -o /dev/null -c "$JAR" -H 'Content-Type: application/json' \
  -X POST "$GW/api/v1/auth/login" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}"
say "logged in as $EMAIL"

# 2. Accounts & Card
post /api/v1/banks/accounts "{\"bankNumber\":\"$BANK\",\"name\":\"Cuenta Corriente\",\"type\":\"CHECKING\",\"currency\":\"ARS\",\"cbu\":\"$CHECKING\",\"alias\":\"demo.checking\"}"
post /api/v1/banks/accounts "{\"bankNumber\":\"$BANK\",\"name\":\"Caja de Ahorro\",\"type\":\"SAVINGS\",\"currency\":\"ARS\",\"cbu\":\"$SAVINGS\",\"alias\":\"demo.savings\"}"
post /api/v1/banks/cards "{\"bankNumber\":\"$BANK\",\"brand\":\"VISA\",\"cardType\":\"GOLD\",\"behavior\":\"CREDIT\",\"cardNumber\":\"$CARD\",\"expiringDate\":\"08/30\",\"closingDay\":20,\"dueDay\":10,\"creditLimit\":500000}"

# 3. Categories
for name in Supermercado Transporte Sueldo; do
  post /api/v1/finances/categories "{\"name\":\"$name\"}"
done

CAT_SUPER=$(curl -s -b "$JAR" "$GW/api/v1/finances/categories" | jq -r '[.data[] | select(.name=="Supermercado")][0].id')
CAT_TRANS=$(curl -s -b "$JAR" "$GW/api/v1/finances/categories" | jq -r '[.data[] | select(.name=="Transporte")][0].id')
CAT_SUELDO=$(curl -s -b "$JAR" "$GW/api/v1/finances/categories" | jq -r '[.data[] | select(.name=="Sueldo")][0].id')
say "categories: Supermercado=$CAT_SUPER Transporte=$CAT_TRANS Sueldo=$CAT_SUELDO"

# 4. Transactions
THIS_MONTH=$(date +%Y-%m)
LAST_MONTH=$(date -d "$(date +%Y-%m-01) -1 month" +%Y-%m)

tx() { # tx <from> <to> <amount> <categoryId> <desc> <date> <method>
  post /api/v1/finances/transactions \
    "{\"fromCbu\":\"$1\",\"toCbu\":\"$2\",\"amount\":\"$3\",\"currency\":\"ARS\",\"categoryId\":$4,\"description\":\"$5\",\"date\":\"$6\",\"paymentMethod\":\"$7\"}"
}

# The budgets read expense spend, and an expense means money leaving the wallet:
# owned → owned is a transfer, owned → external is the spend the budget sees.
EXISTING_SPEND=$(bff_count "/api/v1/bff/categories?currency=ARS&secondary=none" '.data.kpis.data.spent.amount // "0" | tonumber | floor')
if [ "$EXISTING_SPEND" -gt 0 ]; then
  say "budget spend already visible, skipping transaction seeding"
else
  # income, current and previous month
  tx "$EXTERNAL" "$CHECKING" 1450000.00 "$CAT_SUELDO" "Sueldo"        "$THIS_MONTH-05" TRANSFER
  tx "$EXTERNAL" "$CHECKING" 1380000.00 "$CAT_SUELDO" "Sueldo"        "$LAST_MONTH-05" TRANSFER
  # spend, current month — Supermercado is deliberately over its cap
  tx "$CHECKING" "$EXTERNAL"  185000.00 "$CAT_SUPER"  "Coto"          "$THIS_MONTH-08" DEBIT_CARD
  tx "$CHECKING" "$EXTERNAL"  142500.50 "$CAT_SUPER"  "Jumbo"         "$THIS_MONTH-15" CREDIT_CARD
  tx "$CHECKING" "$EXTERNAL"   38200.00 "$CAT_TRANS"  "SUBE"          "$THIS_MONTH-03" DEBIT_CARD
  tx "$CHECKING" "$EXTERNAL"   21750.00 "$CAT_TRANS"  "Cabify"        "$THIS_MONTH-19" CREDIT_CARD
  # spend, previous month
  tx "$CHECKING" "$EXTERNAL"  156000.00 "$CAT_SUPER"  "Coto"          "$LAST_MONTH-09" DEBIT_CARD
  tx "$CHECKING" "$EXTERNAL"   33400.00 "$CAT_TRANS"  "SUBE"          "$LAST_MONTH-02" DEBIT_CARD
fi

# 5. Budget that trips its threshold
Y=$(date +%Y); M=$(date +%-m)
curl -sf -o /dev/null -b "$JAR" -H 'Content-Type: application/json' \
  -X PUT "$GW/api/v1/finances/budgets/$CAT_SUPER" \
  -d "{\"amount\":\"250000\",\"currency\":\"ARS\",\"alertThresholdPct\":\"80\",\"year\":$Y,\"month\":$M}"
say "budget created/updated for category $CAT_SUPER"

# 6. Loan with installments
EXISTING_LOANS=$(bff_count "/api/v1/bff/banks?currency=ARS&secondary=none" '.data.loans.data | length')
if [ "$EXISTING_LOANS" -gt 0 ]; then
  say "loans already exist, skipping loan seeding"
else
  post /api/v1/banks/loans "{\"bankNumber\":\"$BANK\",\"destinationAccountCbu\":\"$CHECKING\",\"name\":\"Préstamo personal\",\"principal\":\"600000\",\"interestRate\":\"75.0\",\"totalInstallments\":12,\"startDate\":\"$LAST_MONTH-01\"}"
fi

# 7. Import run
EXISTING_IMPORTS=$(bff_count "/api/v1/bff/imports" '.data.history.data | length')
if [ "$EXISTING_IMPORTS" -gt 0 ]; then
  say "imports already exist, skipping import seeding"
else
  printf 'fecha,descripcion,importe\n%s-11,Farmacia,-24500.00\n%s-12,Kiosco,-6800.00\n' "$THIS_MONTH" "$THIS_MONTH" > /tmp/demo-statement.csv
  PREVIEW=$(curl -s -b "$JAR" -X POST "$GW/api/v1/upload/csv/preview" -F "file=@/tmp/demo-statement.csv" -F "accountCbu=$CHECKING")
  echo "$PREVIEW" | jq -e '.data' >/dev/null || { echo "preview failed: $PREVIEW" >&2; exit 1; }

  TEMP_KEY=$(echo "$PREVIEW" | jq -r '.data.tempKey // .data.previewId')
  post /api/v1/upload/csv/confirm \
    "{\"tempKey\":\"$TEMP_KEY\",\"accountCbu\":\"$CHECKING\",\"bankNumber\":\"$BANK\",\"dateCol\":0,\"descCol\":1,\"montoCol\":2,\"dateFormat\":\"yyyy-MM-dd\",\"fileType\":\"CSV\"}"
  say "import run confirmed: $(cat /tmp/post.out | jq -c '.data' 2>/dev/null)"
fi

# 8. Holdings so Inversiones has positions
EXISTING_HOLDINGS=$(bff_count "/api/v1/investments/holdings?page=0&size=1" '.data.totalElements // 0')
if [ "$EXISTING_HOLDINGS" -gt 0 ]; then
  say "holdings already exist, skipping holding seeding"
else
  post /api/v1/investments/holdings "{\"bankNumber\":\"$BANK\",\"fundingCbu\":\"$CHECKING\",\"ticker\":\"YPFD\",\"name\":\"YPF S.A.\",\"assetType\":\"STOCK\",\"quantity\":50,\"avgPurchasePrice\":32000,\"currency\":\"ARS\"}"
  post /api/v1/investments/holdings "{\"bankNumber\":\"$BANK\",\"fundingCbu\":\"$CHECKING\",\"ticker\":\"AAPL\",\"name\":\"Apple Inc. CEDEAR\",\"assetType\":\"CEDEAR\",\"quantity\":30,\"avgPurchasePrice\":21500,\"currency\":\"ARS\"}"
fi

# 9. Every seeded entity must be visible through the BFF it belongs to.
verify "transactions"       "/api/v1/bff/transactions?currency=ARS&secondary=none&page=0&size=1" '.data.page.data.totalElements // 0'
verify "budgets"            "/api/v1/bff/categories?currency=ARS&secondary=none"                 '.data.budgets.data | length'
verify "budget spend"       "/api/v1/bff/categories?currency=ARS&secondary=none"                 '.data.kpis.data.spent.amount // "0" | tonumber | floor'
verify "loans"              "/api/v1/bff/banks?currency=ARS&secondary=none"                      '.data.loans.data | length'
verify "import history"     "/api/v1/bff/imports"                                                '.data.history.data | length'
verify "holding positions"  "/api/v1/bff/investments?currency=ARS&secondary=none"                '.data.positions.data | length'

say "Demo user seeding completed successfully."
