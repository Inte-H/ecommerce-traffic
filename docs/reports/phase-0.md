# Phase 0 보고서 — no-lock baseline

- **브랜치**: `phase-0/baseline-no-locking`
- **상태**: 측정 완료 — 졸업 조건 2/2 충족 (2026-08-17). 해석 섹션(3, 4) 작성 중
- **구현 정책**: SELECT stock → 조건 체크 → UPDATE stock 을 동시성 제어 없이 실행하는 의도적 결함 코드 (CONTEXT.md "No-lock baseline")

## 졸업 조건 (시작 전 선언)

정량 신호 2개를 선언한다. **둘 중 최소 하나가 충족돼야 졸업** (CONTEXT.md 판정 규칙). 둘 다 미충족이면 부하 시나리오를 더 가혹하게 만들거나 race 미발생 원인을 진단한다.

| # | 신호 | 측정 방법 | 충족 기준 |
|---|---|---|---|
| 1 | **Oversold** | 부하 구간에 판매된 수량 합계가 부하 시작 시점 stock 을 초과 | `부하 중 판매 수량 − 초기 stock > 0` |
| 2 | **Stock 음수** | `products.stock_qty` 가 0 미만으로 하락 (lost update 가시 증거) | `stock_qty < 0` 관측 |

### 측정 SQL

시드 데이터에 과거 주문이 이미 존재하므로, 부하 **전** 기준값을 기록하고 부하 **후** 차분으로 판정한다. (`:pid` = k6 `PRODUCT_ID`)

```sql
-- [부하 전] 기준값 기록
SELECT stock_qty AS initial_stock FROM products WHERE id = :pid;
SELECT COALESCE(SUM(quantity), 0) AS baseline_sold
FROM order_items WHERE product_id = :pid;

-- [부하 후] 신호 1: oversold 판정
SELECT COALESCE(SUM(quantity), 0) - :baseline_sold AS sold_during_load
FROM order_items WHERE product_id = :pid;
-- oversold = sold_during_load - :initial_stock  (> 0 이면 충족)

-- [부하 후] 신호 2: stock 음수 판정
SELECT id, stock_qty FROM products WHERE id = :pid AND stock_qty < 0;
```

## 1. 측정 표

측정 일시: 2026-08-17 12:51 KST (1회 실행). 실행 커맨드:

```
k6 run --env PRODUCT_ID=1 --env BASE_URL=http://localhost:8080 load-test/flash-sale.js
```

| 항목 | 값 |
|---|---|
| 부하 도구 / 시나리오 | k6 v2.2.0, `load-test/flash-sale.js` (ramping-vus) |
| VU / 지속 시간 | 0→100 (5s) → 500 (20s) → 0 (5s), 총 30s |
| 총 요청 수 | 54,636 (≈1,816 rps) |
| 성공 (2xx) | 125 (201 Created) |
| 재고 부족 거절 (409) | 54,511 |
| 오류 (5xx / 기타) | 0 (check `status is 200/201/409` 100% 통과) |
| 응답 시간 | med 23.2ms · p90 78.5ms · **p95 104.0ms** · max 951ms |
| 초기 stock (`initial_stock`) | 106 |
| 부하 전 누적 판매 (`baseline_sold`) | 311 |
| 부하 중 판매 수량 (`sold_during_load`) | 125 (= 부하 중 생성된 orders 125건 × quantity 1) |
| 부하 후 `stock_qty` | **-19** |

k6 원시 요약: [`phase-0-artifacts/k6-summary-2026-08-17.json`](./phase-0-artifacts/k6-summary-2026-08-17.json)

### 측정 환경

- WSL2 (8 vCPU / 12 GB), 앱·DB·k6 모두 같은 WSL 인스턴스에서 실행 (네트워크 홉 없음 → 지연 수치는 로컬 기준)
- PostgreSQL 16.4 (사용자 공간 바이너리, `max_connections=200`), 앱 HikariCP `maximum-pool-size: 20`
- 앱: `bootJar` 실행. Phase 0 코드가 쓰지 않는 Redis(Redisson)/Kafka 자동설정은 실행 인자 `--spring.autoconfigure.exclude=...` 로 제외 (코드 변경 없음)
- jOOQ 생성 코드는 `infrastructure/docker/postgres/01_schema.sql` 기준으로 재생성 (`./gradlew :api-server:generateJooq -PjooqDbUrl=jdbc:postgresql://localhost:5432/ecommerce`)

## 2. 졸업 조건 충족 증거

측정 SQL 결과 원본 (`:pid = 1`, `:baseline_sold = 311`, `:initial_stock = 106`):

```
-- 신호 1
SELECT COALESCE(SUM(quantity), 0) - 311 AS sold_during_load,
       (COALESCE(SUM(quantity), 0) - 311) - 106 AS oversold
FROM order_items WHERE product_id = 1;
 sold_during_load | oversold
------------------+---------
              125 |       19

-- 신호 2
SELECT id, stock_qty FROM products WHERE id = 1;
 id | stock_qty
----+----------
  1 |      -19
```

| 신호 | 결과 | 충족 여부 |
|---|---|---|
| 1. Oversold | `sold_during_load(125) − initial_stock(106) = 19 > 0` | ☑ |
| 2. Stock 음수 | `stock_qty = -19 < 0` | ☑ |

<!-- TODO(사용자): 위 원본에 대한 해석. 예) oversold 19 와 stock -19 가 정확히 일치한다는 사실이
     "SELECT-check-UPDATE" 경로의 어느 지점이 경합했는지에 대해 무엇을 말해 주는가? -->

## 3. 코틀린 기능 인덱스

<!-- TODO(사용자): 이 phase 에서 자연스럽게 등장한 Kotlin 기능 회고. 예: sealed interface(OrderStatus), value class(ID 타입), ... -->

## 4. 다음 phase 동기부여

<!-- TODO(사용자): 측정 결과가 드러낸 문제 → 다음 phase 에서 도입할 최소 변화. 어떤 동시성 제어를 쓸지는 측정 결과를 본 뒤 결정 (README 학습 의도). -->
