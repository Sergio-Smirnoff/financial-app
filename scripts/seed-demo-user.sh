#!/usr/bin/env bash
# Seeds a deterministic demo user so every BFF section returns non-empty data.
# Idempotent: every entity is looked up by its natural key before it is created, so a second run in
# the same month changes nothing. A run in a later month adds that month's dated rows once.
set -euo pipefail
shopt -s inherit_errexit

GW="${GATEWAY_URL:-http://localhost:8080}"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
JAR="$WORK/cookies.txt"
EMAIL=demo@financial.app
PASSWORD='Demo!2026pass'

CHECKING=0170099200000000000017
SAVINGS=0170099200000000000024
# Not owned by the demo user: spends must leave the wallet or the ownership-derived
# kind classifies them as internal transfers and budgets never see them.
EXTERNAL=2850590940090418135201
CARD=4509953566233704
BANK=017
LOAN_NAME='Préstamo personal'

THIS_MONTH=$(date +%Y-%m)
LAST_MONTH=$(date -d "$(date +%Y-%m-01) -1 month" +%Y-%m)

say() { printf '  %s\n' "$*"; }

get() { # get <path> — prints the body; any non-2xx aborts the run
  curl -sf -b "$JAR" "$GW$1"
}

post() { # post <path> <json>
  local code
  code=$(curl -s -o "$WORK/post.out" -w '%{http_code}' -b "$JAR" -c "$JAR" \
    -H 'Content-Type: application/json' -X POST "$GW$1" -d "$2")
  case "$code" in
    200|201) return 0 ;;
    409)     say "exists, skipping: $1" ; return 0 ;;
    *)       echo "POST $1 failed ($code): $(cat "$WORK/post.out")" >&2 ; return 1 ;;
  esac
}

has() { # has <json> <jq-filter-returning-boolean> [jq args...]
  local json=$1 filter=$2
  shift 2
  jq -e "$@" "$filter" <<<"$json" >/dev/null
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

# 1. Register & login
curl -s -o /dev/null -c "$JAR" -H 'Content-Type: application/json' \
  -X POST "$GW/api/v1/auth/register" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\",\"firstName\":\"Demo\",\"lastName\":\"Usuario\"}" || true

curl -sf -o /dev/null -c "$JAR" -H 'Content-Type: application/json' \
  -X POST "$GW/api/v1/auth/login" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}"
say "logged in as $EMAIL"

# 2. Accounts & card, keyed by CBU and card number
accounts=$(get /api/v1/banks/accounts)
ensure_account() { # ensure_account <cbu> <json>
  if has "$accounts" 'any(.data[]; .cbu == $cbu)' --arg cbu "$1"; then
    say "account exists: $1"
  else
    post /api/v1/banks/accounts "$2"
  fi
}
ensure_account "$CHECKING" "{\"bankNumber\":\"$BANK\",\"name\":\"Cuenta Corriente\",\"type\":\"CHECKING\",\"currency\":\"ARS\",\"cbu\":\"$CHECKING\",\"alias\":\"demo.checking\"}"
ensure_account "$SAVINGS" "{\"bankNumber\":\"$BANK\",\"name\":\"Caja de Ahorro\",\"type\":\"SAVINGS\",\"currency\":\"ARS\",\"cbu\":\"$SAVINGS\",\"alias\":\"demo.savings\"}"

cards=$(get /api/v1/banks/cards)
if has "$cards" 'any(.data[]; .cardNumber == $card)' --arg card "$CARD"; then
  say "card exists: $CARD"
else
  post /api/v1/banks/cards "{\"bankNumber\":\"$BANK\",\"brand\":\"VISA\",\"cardType\":\"GOLD\",\"behavior\":\"CREDIT\",\"cardNumber\":\"$CARD\",\"expiringDate\":\"08/30\",\"closingDay\":20,\"dueDay\":10,\"creditLimit\":500000}"
fi

# 3. Categories, keyed by name
category_id() { # category_id <name> — prints the id, or nothing
  local categories
  categories=$(get /api/v1/finances/categories)
  jq -r --arg name "$1" '[.data[] | select(.name == $name)][0].id // empty' <<<"$categories"
}

ensure_category() { # ensure_category <name>
  local id
  id=$(category_id "$1")
  if [ -n "$id" ]; then
    say "category exists: $1"
  else
    post /api/v1/finances/categories "{\"name\":\"$1\"}"
  fi
}

for name in Supermercado Transporte Sueldo; do
  ensure_category "$name"
done

CAT_SUPER=$(category_id Supermercado)
CAT_TRANS=$(category_id Transporte)
CAT_SUELDO=$(category_id Sueldo)
say "categories: Supermercado=$CAT_SUPER Transporte=$CAT_TRANS Sueldo=$CAT_SUELDO"

# 4. Transactions, keyed by (description, date, amount)
tx() { # tx <from> <to> <amount> <categoryId> <desc> <date> <method>
  local query page
  query=$(jq -rn --arg q "$5" '$q | @uri')
  page=$(get "/api/v1/finances/transactions?from=$6&to=$6&q=$query&size=50")
  if has "$page" 'any(.data.content[]; (.amount | tonumber) == ($amount | tonumber))' --arg amount "$3"; then
    say "transaction exists: $5 on $6"
    return 0
  fi
  post /api/v1/finances/transactions \
    "{\"fromCbu\":\"$1\",\"toCbu\":\"$2\",\"amount\":\"$3\",\"currency\":\"ARS\",\"categoryId\":$4,\"description\":\"$5\",\"date\":\"$6\",\"paymentMethod\":\"$7\"}"
}

tx "$EXTERNAL" "$CHECKING" 1450000.00 "$CAT_SUELDO" "Sueldo" "$THIS_MONTH-05" TRANSFER
tx "$EXTERNAL" "$CHECKING" 1380000.00 "$CAT_SUELDO" "Sueldo" "$LAST_MONTH-05" TRANSFER
tx "$CHECKING" "$EXTERNAL"  185000.00 "$CAT_SUPER"  "Coto"   "$THIS_MONTH-08" DEBIT_CARD
tx "$CHECKING" "$EXTERNAL"  142500.50 "$CAT_SUPER"  "Jumbo"  "$THIS_MONTH-15" CREDIT_CARD
tx "$CHECKING" "$EXTERNAL"   38200.00 "$CAT_TRANS"  "SUBE"   "$THIS_MONTH-03" DEBIT_CARD
tx "$CHECKING" "$EXTERNAL"   21750.00 "$CAT_TRANS"  "Cabify" "$THIS_MONTH-19" CREDIT_CARD
tx "$CHECKING" "$EXTERNAL"  156000.00 "$CAT_SUPER"  "Coto"   "$LAST_MONTH-09" DEBIT_CARD
tx "$CHECKING" "$EXTERNAL"   33400.00 "$CAT_TRANS"  "SUBE"   "$LAST_MONTH-02" DEBIT_CARD

# 5. Budget that trips its threshold — PUT is an upsert on (user, category, year, month)
Y=$(date +%Y); M=$(date +%-m)
curl -sf -o /dev/null -b "$JAR" -H 'Content-Type: application/json' \
  -X PUT "$GW/api/v1/finances/budgets/$CAT_SUPER" \
  -d "{\"amount\":\"250000\",\"currency\":\"ARS\",\"alertThresholdPct\":\"80\",\"year\":$Y,\"month\":$M}"
say "budget created/updated for category $CAT_SUPER"

# 6. Loan, keyed by name
loans=$(get /api/v1/banks/loans)
if has "$loans" 'any(.data[]; .name == $name)' --arg name "$LOAN_NAME"; then
  say "loan exists: $LOAN_NAME"
else
  post /api/v1/banks/loans "{\"bankNumber\":\"$BANK\",\"destinationAccountCbu\":\"$CHECKING\",\"name\":\"$LOAN_NAME\",\"principal\":\"600000\",\"interestRate\":\"75.0\",\"totalInstallments\":12,\"startDate\":\"$LAST_MONTH-01\"}"
fi

# 7. Import run, keyed by (account, period start) among runs that still count
history=$(get /api/v1/upload/history)
if has "$history" 'any(.data[]; .accountCbu == $cbu and .periodFrom == $from and .status != "UNDONE" and .status != "FAILED")' \
     --arg cbu "$CHECKING" --arg from "$THIS_MONTH-11"; then
  say "import run exists: $CHECKING from $THIS_MONTH-11"
else
  printf 'fecha,descripcion,importe\n%s-11,Farmacia,-24500.00\n%s-12,Kiosco,-6800.00\n' "$THIS_MONTH" "$THIS_MONTH" > "$WORK/statement.csv"
  PREVIEW=$(curl -s -b "$JAR" -X POST "$GW/api/v1/upload/csv/preview" -F "file=@$WORK/statement.csv" -F "accountCbu=$CHECKING")
  echo "$PREVIEW" | jq -e '.data' >/dev/null || { echo "preview failed: $PREVIEW" >&2; exit 1; }
  TEMP_KEY=$(echo "$PREVIEW" | jq -r '.data.tempKey // .data.previewId')
  post /api/v1/upload/csv/confirm \
    "{\"tempKey\":\"$TEMP_KEY\",\"accountCbu\":\"$CHECKING\",\"bankNumber\":\"$BANK\",\"dateCol\":0,\"descCol\":1,\"montoCol\":2,\"dateFormat\":\"yyyy-MM-dd\",\"fileType\":\"CSV\"}"
  say "import run confirmed: $(jq -c '.data' "$WORK/post.out" 2>/dev/null)"
fi

# 8. Holdings, keyed by ticker
holdings=$(get "/api/v1/investments/holdings?page=0&size=100")
ensure_holding() { # ensure_holding <ticker> <json>
  if has "$holdings" 'any(.data.content[]; .ticker == $ticker)' --arg ticker "$1"; then
    say "holding exists: $1"
  else
    post /api/v1/investments/holdings "$2"
  fi
}
ensure_holding YPFD "{\"bankNumber\":\"$BANK\",\"fundingCbu\":\"$CHECKING\",\"ticker\":\"YPFD\",\"name\":\"YPF S.A.\",\"assetType\":\"STOCK\",\"quantity\":50,\"avgPurchasePrice\":32000,\"currency\":\"ARS\"}"
ensure_holding AAPL "{\"bankNumber\":\"$BANK\",\"fundingCbu\":\"$CHECKING\",\"ticker\":\"AAPL\",\"name\":\"Apple Inc. CEDEAR\",\"assetType\":\"CEDEAR\",\"quantity\":30,\"avgPurchasePrice\":21500,\"currency\":\"ARS\"}"

# 9. Every seeded entity must be visible through the BFF it belongs to.
verify "transactions"       "/api/v1/bff/transactions?currency=ARS&secondary=none&page=0&size=1" '.data.page.data.totalElements // 0'
verify "budgets"            "/api/v1/bff/categories?currency=ARS&secondary=none"                 '.data.budgets.data | length'
verify "budget spend"       "/api/v1/bff/categories?currency=ARS&secondary=none"                 '.data.kpis.data.spent.amount // "0" | tonumber | floor'
verify "loans"              "/api/v1/bff/banks?currency=ARS&secondary=none"                      '.data.loans.data | length'
verify "import history"     "/api/v1/bff/imports"                                                '.data.history.data | length'
verify "holding positions"  "/api/v1/bff/investments?currency=ARS&secondary=none"                '.data.positions.data | length'

say "Demo user seeding completed successfully."
