# Phase 1 보고서 — SELECT … FOR UPDATE (비관적 행 잠금)

- **브랜치**: `phase-1/select-for-update`
- **상태**: 진행 중 (구현 전)
- **동기 (Phase 0 결과)**: `findStock()` 의 SELECT 가 락을 잡지 않아 `if (stock < quantity)` 판단과 `decrease()` 차감이 서로 다른 시점의 재고를 봤다. 차감 자체는 원자적이었고(판매 125 = 재고 감소 125), 뚫린 것은 판단뿐이다 → oversold 19 = 재고 −19. ([phase-0.md](./phase-0.md) 섹션 2)
- **구현 정책**: 진단된 지점만 막는 최소 변화 — `findStock()` 의 SELECT 에 행 잠금(`FOR UPDATE`)을 걸어 판단→차감이 같은 트랜잭션의 같은 재고 위에서 이뤄지게 한다. 서비스 흐름·스키마는 Phase 0 그대로 (변화 지점 1곳 → 측정 비교가 깨끗해야 함).
- **보류한 후보**: 조건부 UPDATE(`WHERE stock_qty >= ?`, 갱신 행 수로 판정), 낙관적 잠금(version 컬럼). flash-sale 에는 조건부 UPDATE 가 더 단순·빠르지만, 비관적 락의 비용을 먼저 측정으로 확인한 뒤 이후 phase 에서 옮기며 차이를 재기 위해 지금은 택하지 않는다.

## 졸업 조건 (시작 전 선언)

Phase 0 과 **같은 부하·같은 초기 재고**(`RESET_STOCK=106`, `load-test/flash-sale.js` 30s 시나리오)에서 판정한다. Phase 0 은 "둘 중 하나"였지만 이번 phase 는 정합성이 목적이므로 **둘 다 충족**해야 졸업한다.

| # | 신호 | 측정 방법 | 충족 기준 |
|---|---|---|---|
| 1 | **Oversold 없음** | 부하 중 판매 수량 − 초기 stock (`load-test/measure.sh` 출력 `oversold`) | `oversold ≤ 0` (= 판매 수량 ≤ 106) |
| 2 | **Stock 비음수** | 부하 후 `products.stock_qty` | `stock_qty ≥ 0` (기대값: 정확히 0) |

부수 관측 (졸업 조건은 아니지만 반드시 기록 — Phase 2 동기부여의 재료):

| 항목 | Phase 0 기준선 | Phase 1 |
|---|---|---|
| 총 요청 수 / rps | 54,636 / ≈1,816 | _측정 후 기입_ |
| p95 응답 시간 | 104.0ms (med 23.2 · p90 78.5 · max 951) | _측정 후 기입_ |
| 5xx | 0 | _측정 후 기입_ (락 대기 타임아웃·풀 고갈이 5xx 로 새는지) |

병목이 **DB 행 락 대기**인지 **HikariCP 풀(20) 고갈**인지 구분해서 본다. 수치만으로 원인을 못 짚으면 그 시점이 README 가 말한 관측(Prometheus/Grafana) 도입 phase 다.

### 측정 절차

앱(FOR UPDATE 반영 빌드)과 PostgreSQL 이 떠 있는 상태에서:

```
RESET_STOCK=106 load-test/measure.sh
```

스크립트가 부하 전 기준값 기록 → k6 → 판정 SQL(Phase 0 과 동일한 차분 방식)까지 수행하고, k6 요약 JSON 은 `load-test/out/` 에 남는다. 보고서에는 요약 JSON 을 `phase-1-artifacts/` 로 옮겨 링크한다.

## 1. 측정 표

<!-- TODO(사용자): measure.sh 실행 후 채우기 -->

| 항목 | 값 |
|---|---|
| 부하 도구 / 시나리오 | k6, `load-test/flash-sale.js` (Phase 0 과 동일) |
| VU / 지속 시간 | 0→100 (5s) → 500 (20s) → 0 (5s), 총 30s |
| 총 요청 수 | _측정 후 기입_ |
| 성공 (2xx) | _측정 후 기입_ |
| 재고 부족 거절 (409) | _측정 후 기입_ |
| 오류 (5xx / 기타) | _측정 후 기입_ |
| 응답 시간 | _측정 후 기입_ |
| 초기 stock (`initial_stock`) | 106 |
| 부하 중 판매 수량 (`sold_during_load`) | _측정 후 기입_ |
| 부하 후 `stock_qty` | _측정 후 기입_ |

## 2. 졸업 조건 충족 증거

<!-- TODO(사용자): measure.sh 판정 출력 원본 + 해석. 충족했다면 "비용" 해석(p95·rps 후퇴, 병목 위치)이 이 섹션의 핵심. -->

| 신호 | 결과 | 충족 여부 |
|---|---|---|
| 1. Oversold 없음 | _측정 후 기입_ | ☐ |
| 2. Stock 비음수 | _측정 후 기입_ | ☐ |

## 3. 코틀린 기능 인덱스

<!-- TODO(사용자) -->

## 4. 다음 phase 동기부여

<!-- TODO(사용자): 측정된 비용이 드러낸 문제 → 다음 최소 변화 (조건부 UPDATE / 낙관적 잠금 / 그 외). 측정 결과를 본 뒤 결정. -->
