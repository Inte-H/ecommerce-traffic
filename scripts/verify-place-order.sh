#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"
CUSTOMER_ID="${CUSTOMER_ID:-1}"
PRODUCT_ID="${PRODUCT_ID:-1}"
QUANTITY="${QUANTITY:-1}"
ADDRESS_ID="${ADDRESS_ID:-1}"

DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-ecommerce}"
DB_USER="${DB_USER:-user}"
DB_PASSWORD="${DB_PASSWORD:-password}"

payload=$(printf '{"customerId":%s,"productId":%s,"quantity":%s,"addressId":%s}' \
  "$CUSTOMER_ID" "$PRODUCT_ID" "$QUANTITY" "$ADDRESS_ID")

if command -v psql >/dev/null 2>&1; then
  echo "Before:"
  PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
    -c "select id, stock_qty from products where id = ${PRODUCT_ID};"
fi

tmp_body="$(mktemp)"
http_code=$(
  curl -sS -o "$tmp_body" -w '%{http_code}' \
    -X POST "${BASE_URL}/api/orders/place" \
    -H 'Content-Type: application/json' \
    -d "$payload"
)

echo "HTTP ${http_code}"
cat "$tmp_body"
echo

if [ "$http_code" != "201" ]; then
  rm -f "$tmp_body"
  echo "Expected HTTP 201, got ${http_code}" >&2
  exit 1
fi

order_id=$(sed -n 's/.*"orderId"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$tmp_body" | head -1)
rm -f "$tmp_body"

if [ -z "$order_id" ]; then
  echo "Response did not contain numeric orderId" >&2
  exit 1
fi

echo "Created orderId=${order_id}"

if command -v psql >/dev/null 2>&1; then
  echo "After:"
  PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
    -c "select id, stock_qty from products where id = ${PRODUCT_ID};"
  PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
    -c "select id, customer_id, address_id, status, total_amount from orders where id = ${order_id};"
  PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
    -c "select order_id, product_id, quantity, unit_price, subtotal from order_items where order_id = ${order_id};"
fi
