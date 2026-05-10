# ecommerce-traffic

Kotlin + Postgres 기반의 고동시성 트랜잭션 학습 프로젝트. e-commerce 주문/재고 도메인을 무대로, 단계별 동시성 제어 전략의 행동 차이를 측정한다.

## Language

### 도메인 개념

**Product**:
판매 단위. `products.id` 한 row가 한 Product를 표현하며 가격(`price`)과 재고(`stock_qty`)를 직접 보유한다.
_Avoid_: Item, SKU(`products.sku`는 Product의 식별 코드일 뿐 동의어 아님)

**Order**:
한 Customer가 한 시점에 만든 구매 단위. `OrderStatus` sealed interface로 상태 전이를 컴파일 타임에 강제한다.
_Avoid_: Purchase, transaction(transaction은 DB 트랜잭션 의미로 예약)

**Order Item**:
한 Order 내의 한 Product에 대한 라인. `(productId, quantity, unitPrice)` 튜플.
_Avoid_: Line, row

**Customer**:
주문을 만드는 주체. 학습 단계에서는 `customers.id`만 사용하고 인증/권한은 무시한다.
_Avoid_: User, account, buyer

**Stock**:
**Product가 보유한 판매 가능 수량**. 본 학습 단계의 정의는 `products.stock_qty` 단일 컬럼. Inventory aggregate(reserve/commit 모델)는 휴면 상태이며 이 정의의 "stock"이 아니다.
_Avoid_: Inventory(휴면 aggregate 이름), 재고(영문 stock으로 통일하되 보고서에서 한국어 사용 시 "재고")

**Inventory aggregate (휴면)**:
`Inventory.kt`의 reserve/release/commit 3단계 워크플로 모델. 본 학습 단계에서는 *사용하지 않으며*, 후속 Saga 학습 phase에서 재도입 예정. "Stock"의 정의에 포함되지 않는다.
_Avoid_: 현재 phase에서 이 단어를 쓰지 말 것

### 학습 사이클 개념

**Phase**:
이 프로젝트의 학습 단위. 한 phase는 "구현 → k6 부하 → 측정 → 정량 졸업 조건 판정 → 보고서"의 한 사이클이며, 별도 브랜치(`phase-N/<slug>`)로 분리된다.
_Avoid_: Step, stage

**졸업 조건 (graduation criteria)**:
한 Phase를 끝내고 다음으로 가는 *정량적* 신호 집합 (최소 2개). Phase 시작 전에 보고서 상단에 박는다. 시간 박스가 아니다.
_Avoid_: 완료 조건, exit criteria

**Phase 보고서**:
`docs/reports/phase-N.md`. Phase 종료 시 작성되며 (a) 측정 표 (b) 졸업 조건 충족 증거 (c) 코틀린 기능 인덱스 (d) 다음 phase 동기부여 4개 섹션을 가진다.

**코틀린 기능 인덱스**:
매 Phase 보고서의 회고 섹션. "이 phase에서 자연스럽게 등장한 Kotlin 기능"을 목록화 — sealed class, value class, lambda with receiver, type-safe builder 등. DSL/언어 학습은 이 섹션을 통해 흡수한다.

### 동시성 현상 (측정 표적)

**Race condition**:
서로 다른 트랜잭션이 동시 진입했을 때 직렬 실행 결과로 도달 불가능한 상태가 발생하는 현상. Phase 0이 의도적으로 노출시키는 표적.

**Lost update**:
두 트랜잭션이 같은 행을 SELECT한 뒤 각자의 결과로 UPDATE해서, 한쪽 갱신이 사라지는 현상. Phase 0의 측정 항목.

**Oversold**:
판매된 수량이 초기 stock을 초과하는 상태. Phase 0의 핵심 측정 항목 — 부하 종료 후 `SELECT COUNT(*) FROM orders WHERE product_id = ?` > 초기 stock.

**Stock 음수 (negative stock)**:
`products.stock_qty`가 0 미만으로 떨어진 상태. Lost update의 가시적 증거.

**No-lock baseline**:
Phase 0의 구현 정책. SELECT stock → 조건 체크 → UPDATE stock을 동시성 제어(트랜잭션 격리 수준 강화/락/version) 없이 실행. 의도적 결함 코드.

### 동시성 제어 어휘 (후속 phase 후보)

**Pessimistic lock**:
SELECT 시점에 락을 잡아 동시 접근을 직렬화하는 전략. PostgreSQL에서는 `SELECT ... FOR UPDATE`.

**Optimistic lock**:
version 컬럼을 두고 UPDATE의 WHERE 절에 version 조건을 걸어 충돌 시 retry하는 전략.

**MVCC**:
PostgreSQL의 다중 버전 동시성 제어. 한 행의 갱신이 새 row 버전을 만들고 기존 버전은 스냅샷에서 읽힘. Phase 0 측정 시 "왜 lost update가 일어나는가"의 설명 도구.

**SKIP LOCKED**:
`SELECT ... FOR UPDATE SKIP LOCKED` — 락이 걸린 행을 건너뛰고 다음 행을 가져오는 PostgreSQL 기능. 큐 패턴에 사용.

## Relationships

- A **Customer** places one or more **Orders**
- An **Order** contains one or more **Order Items**
- An **Order Item** references exactly one **Product**
- A **Product** has one **Stock** value (`products.stock_qty`)
- A **Phase** produces one **Phase 보고서** and references the prior **Phase 보고서** as motivation
- A **Phase** has explicit **졸업 조건** declared at start

## Example dialogue

> **Dev:** "Phase 0에서 `Order`를 만들 때 `Inventory` aggregate의 `reserve`를 호출해야 하나요?"
> **Domain expert:** "아니, 현재 phase의 **Stock**은 `products.stock_qty`다. **Inventory** aggregate는 휴면이고 학습 무대 밖이야. **Order**가 만들어질 때 `products.stock_qty`를 직접 차감한다."

> **Dev:** "Phase 0에서 **Lost update**가 안 보이면 다음 phase로 넘어가도 됩니까?"
> **Domain expert:** "아니. **졸업 조건**은 `oversold > 0` OR `stock 음수 도달` 중 *최소 하나*가 충족돼야 한다. 둘 다 안 보이면 부하 시나리오를 더 가혹하게 만들거나 race가 일어나지 않는 이유를 진단해야 한다 — phase 0 자체가 race를 *측정 가능한 형태로* 노출시키는 게 목적이니까."

## Flagged ambiguities

- **"재고 차감"** — 두 가지 의미가 있었다: (1) `Inventory.commit(qty)` (도메인 aggregate의 reserve→commit 워크플로 마지막 단계), (2) `UPDATE products SET stock_qty = stock_qty - ? WHERE id = ?` (단일 컬럼 직접 차감). **본 학습 단계에서는 (2)로 고정**. (1)은 휴면 aggregate에만 존재하며 사용하지 않는다.
- **"Stock"** — `Inventory.stockQuantity`(도메인의 raw stock), `Inventory.available`(reserved 차감), `products.stock_qty`(DB 컬럼) 셋이 다른 값을 가질 수 있었다. 본 학습 단계에서는 **`products.stock_qty`만이 Stock**.
- **"Inventory"** — 영어 일반어로 "재고"를 가리키지만, 본 프로젝트에서는 휴면 aggregate의 이름으로 예약. 일반 의미의 "재고"는 **Stock**을 사용.
