#!/usr/bin/env bash
# Phase 측정 사이클 자동화: [재고 리셋] → 부하 전 기준값 기록 → k6 → 부하 후 판정 SQL
#
# 전제: 앱(BASE_URL)과 PostgreSQL 이 이미 떠 있어야 한다.
# 판정 SQL 은 docs/reports/phase-0.md "측정 SQL" 과 동일하다 (기준값 차분 방식).
#
# 사용 예:
#   load-test/measure.sh                                  # 상품 1, 30s 시나리오
#   RESET_STOCK=106 load-test/measure.sh                  # 부하 전에 stock_qty 를 106 으로 맞춘 뒤 실행 (phase 간 비교용)
#   K6_ARGS="--vus 1 --iterations 1" load-test/measure.sh # 스크립트 점검용 1회 호출
#
# 환경변수 (모두 선택):
#   PRODUCT_ID   측정 대상 상품 id                        (기본 1)
#   BASE_URL     앱 주소                                  (기본 http://localhost:8080)
#   RESET_STOCK  지정 시 부하 전에 stock_qty 를 이 값으로 UPDATE
#   PSQL         SQL 실행기 (psql 호환: -c "<sql>")       (기본 ~/.local/opt/pgsql-runner/psql, 없으면 PATH 의 psql)
#   K6           k6 실행 파일                             (기본 ~/.local/opt/k6/k6, 없으면 PATH 의 k6)
#   K6_ARGS      k6 run 에 덧붙일 인자
#   OUT_DIR      k6 요약 JSON 저장 위치                   (기본 load-test/out)
set -euo pipefail

cd "$(dirname "$0")/.."

PRODUCT_ID="${PRODUCT_ID:-1}"
BASE_URL="${BASE_URL:-http://localhost:8080}"
OUT_DIR="${OUT_DIR:-load-test/out}"
PSQL="${PSQL:-$HOME/.local/opt/pgsql-runner/psql}"; [ -x "$PSQL" ] || PSQL=psql
K6="${K6:-$HOME/.local/opt/k6/k6}";                 [ -x "$K6" ]   || K6=k6

# 결과 표에서 숫자 한 개만 뽑는다 (psql 실제 바이너리와 JDBC 러너 둘 다 헤더+구분선+값 형식이라 마지막 숫자 줄을 취함)
scalar() {
    "$PSQL" -c "$1" | grep -E '^[[:space:]]*-?[0-9]+[[:space:]]*$' | tail -1 | tr -d '[:space:]'
}

mkdir -p "$OUT_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
SUMMARY="$OUT_DIR/k6-summary-$STAMP.json"

if [ -n "${RESET_STOCK:-}" ]; then
    echo "== 재고 리셋: products.id=$PRODUCT_ID stock_qty=$RESET_STOCK"
    "$PSQL" -c "UPDATE products SET stock_qty = $RESET_STOCK WHERE id = $PRODUCT_ID" >/dev/null
fi

echo "== 부하 전 기준값"
INITIAL_STOCK=$(scalar "SELECT stock_qty FROM products WHERE id = $PRODUCT_ID")
BASELINE_SOLD=$(scalar "SELECT COALESCE(SUM(quantity), 0) FROM order_items WHERE product_id = $PRODUCT_ID")
echo "initial_stock=$INITIAL_STOCK baseline_sold=$BASELINE_SOLD"

if [ "$INITIAL_STOCK" -le 0 ]; then
    echo "!! 부하 전 재고가 0 이하 — oversold 판정이 무의미하다. RESET_STOCK=<양수> 로 리셋한 뒤 다시 실행할 것." >&2
    exit 2
fi

echo "== k6 실행 (요약: $SUMMARY)"
# shellcheck disable=SC2086
"$K6" run --env PRODUCT_ID="$PRODUCT_ID" --env BASE_URL="$BASE_URL" \
    --summary-export="$SUMMARY" ${K6_ARGS:-} load-test/flash-sale.js

echo "== 부하 후 판정"
SOLD_DURING_LOAD=$(scalar "SELECT COALESCE(SUM(quantity), 0) - $BASELINE_SOLD FROM order_items WHERE product_id = $PRODUCT_ID")
FINAL_STOCK=$(scalar "SELECT stock_qty FROM products WHERE id = $PRODUCT_ID")
OVERSOLD=$(( SOLD_DURING_LOAD - INITIAL_STOCK ))

printf '%-22s %s\n' "initial_stock"    "$INITIAL_STOCK"
printf '%-22s %s\n' "baseline_sold"    "$BASELINE_SOLD"
printf '%-22s %s\n' "sold_during_load" "$SOLD_DURING_LOAD"
printf '%-22s %s\n' "final_stock_qty"  "$FINAL_STOCK"
printf '%-22s %s  (%s)\n' "oversold" "$OVERSOLD" "$([ "$OVERSOLD" -gt 0 ] && echo '신호 1 충족' || echo '신호 1 미충족')"
printf '%-22s %s  (%s)\n' "stock < 0"  "$([ "$FINAL_STOCK" -lt 0 ] && echo yes || echo no)" "$([ "$FINAL_STOCK" -lt 0 ] && echo '신호 2 충족' || echo '신호 2 미충족')"
