# Phase 0 보고서 — no-lock baseline

- **브랜치**: `phase-0/baseline-no-locking`
- **상태**: 진행 중 (부하 측정 전)
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

<!-- TODO(사용자): k6 실행 후 채우기. 실행 커맨드 예시:
     k6 run --env PRODUCT_ID=1 --env BASE_URL=http://<host>:8080 load-test/flash-sale.js -->

| 항목 | 값 |
|---|---|
| 부하 도구 / 시나리오 | k6 `load-test/flash-sale.js` |
| VU / 지속 시간 | _측정 후 기입_ |
| 총 요청 수 | _측정 후 기입_ |
| 성공 (2xx) | _측정 후 기입_ |
| 재고 부족 거절 (409) | _측정 후 기입_ |
| 오류 (5xx / 기타) | _측정 후 기입_ |
| p95 응답 시간 | _측정 후 기입_ |
| 초기 stock (`initial_stock`) | _측정 후 기입_ |
| 부하 중 판매 수량 (`sold_during_load`) | _측정 후 기입_ |
| 부하 후 `stock_qty` | _측정 후 기입_ |

## 2. 졸업 조건 충족 증거

<!-- TODO(사용자): 측정 SQL 결과 원본 + 해석. race 가 안 보였다면 그 원인 진단도 여기에. -->

| 신호 | 결과 | 충족 여부 |
|---|---|---|
| 1. Oversold | _측정 후 기입_ | ☐ |
| 2. Stock 음수 | _측정 후 기입_ | ☐ |

## 3. 코틀린 기능 인덱스

<!-- TODO(사용자): 이 phase 에서 자연스럽게 등장한 Kotlin 기능 회고. 예: sealed interface(OrderStatus), value class(ID 타입), ... -->

## 4. 다음 phase 동기부여

<!-- TODO(사용자): 측정 결과가 드러낸 문제 → 다음 phase 에서 도입할 최소 변화. 어떤 동시성 제어를 쓸지는 측정 결과를 본 뒤 결정 (README 학습 의도). -->
