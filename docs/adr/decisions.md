# ADR-001: 데이터베이스 접근 기술 선택 — jOOQ vs JPA

- **Date**: 2026-04-19
- **Status**: Accepted

## Context

대용량 트래픽 처리 프로젝트에서 DB 접근 기술 선택이 필요했다. 주요 후보는 Spring Data JPA와 jOOQ였다.

## Decision

**jOOQ를 선택**한다.

## Rationale

JPA는 멀티 DB 지원을 위해 JPQL이라는 추상화 계층을 사용한다. 이는 솔루션처럼 여러 DB를 지원해야 할 때 의미 있지만, **단일 PostgreSQL을 사용하는 이 프로젝트에서는 불필요한 추상화 비용**만 발생한다.

구체적으로 JPA 추상화에서 대용량 트래픽 시 발생하는 문제:

| 문제 | 원인 | 영향 |
|------|------|------|
| N+1 쿼리 | Lazy Loading | 런타임에서야 발견 |
| 예측 불가 SQL | 자동 생성 쿼리 | EXPLAIN ANALYZE 튜닝 어려움 |
| DB 특화 기능 미사용 | JPQL 한계 | PostgreSQL 윈도우 함수, CTE 사용 불가 |
| 배치 처리 메모리 | 1차 캐시 + 변경 감지 | 대량 INSERT 시 OOM 위험 |

jOOQ를 선택하면:
- **SQL-first**: 실행될 쿼리를 컴파일 타임에 정확히 파악
- **타입 세이프**: 스키마 변경 → 컴파일 에러 → 런타임 에러 방지
- **DB 특화 기능**: `WINDOW FUNCTION`, `WITH RECURSIVE`, `LATERAL JOIN` 직접 사용
- **도메인/영속성 분리 자연스러움**: JPA Entity처럼 `var`, `nullable`, `@Entity` 강제 없음

## Consequences

- jOOQ 코드 생성기 설정 필요 (DB가 올라와 있어야 함)
- `@Transactional`은 Spring의 트랜잭션 관리를 그대로 사용
- Kotlin value class, data class를 도메인 모델에 자유롭게 사용 가능

---

# ADR-002: JVM 버전 선택 — Java 25 LTS

- **Date**: 2026-04-19
- **Status**: Accepted

## Decision

**Java 25 LTS**를 선택한다.

## Rationale

2026년 4월 기준:
- Java 21의 Oracle 무료 업데이트는 2026년 9월 종료 → 신규 프로젝트에 부적합
- Java 25는 2028년까지 무료 업데이트 지원

이 프로젝트 관련 개선사항:
- **JEP 491**: `synchronized` 블록에서 Virtual Thread 피닝 문제 해결 → jOOQ + JDBC 조합에서 성능 최적화
- **Compact Object Headers**: ~22% 메모리 효율 향상 → 대용량 데이터 처리 시 GC 부담 감소
- **Scoped Values**: Virtual Thread 환경에서 ThreadLocal 대체

---

# ADR-003: 동시성 모델 — Kotlin Coroutines + Java Virtual Threads

- **Date**: 2026-04-19
- **Status**: Accepted

## Decision

Kotlin 코루틴과 Java Virtual Threads를 함께 사용한다.

## Rationale

두 기술은 경쟁 관계가 아니라 **상호 보완**한다:

| 역할 | 기술 |
|------|------|
| 비즈니스 흐름 제어, 구조적 동시성, 취소 전파 | Kotlin Coroutines |
| jOOQ JDBC blocking IO 경량화 | Java Virtual Threads |

`spring.threads.virtual.enabled=true` 한 줄로 Virtual Threads 활성화.
코루틴 `Dispatchers.IO` 대신 `VirtualThreadPerTaskExecutor`를 디스패처로 사용하여 JDBC blocking 병목 해소.

---

# ADR-004: 데이터베이스 — PostgreSQL 명시화

- **Date**: 2026-05-10
- **Status**: Accepted

## Context

ADR-001(jOOQ 선택)이 "단일 PostgreSQL을 사용하는 이 프로젝트"를 묵시적 전제로만 깔고 있었으며, DB 자체를 결정한 ADR이 부재했다. Uber의 PostgreSQL→MySQL 마이그레이션 글에서 제기된 비판들을 본 학습 프로젝트의 환경에서 평가한 뒤, PostgreSQL 채택을 명시적으로 기록한다.

## Decision

**PostgreSQL을 유지**한다. 학습 프로젝트의 단일 노드 환경에서 Uber 비판 5가지 중 4가지는 발현되지 않으며, 동시성 학습 주제와의 정합성이 가장 높다.

## Rationale

### 1. 학습 주제와의 정합

본 프로젝트의 학습 표적은 동시성 제어 메커니즘이다. PostgreSQL은 다음 도구를 풍부하게 제공한다:

- `SELECT … FOR UPDATE` / `FOR UPDATE NOWAIT` / `FOR UPDATE SKIP LOCKED`
- Advisory lock (`pg_advisory_xact_lock`)
- `pg_stat_activity` / `pg_locks` / `pg_stat_statements` (관측)
- 트랜잭션 격리 수준 4종 모두 (Read Uncommitted 제외 시 3종)

이 도구 중 다수는 MySQL/InnoDB와 의미·동작이 다르거나 부재하다.

### 2. Uber 비판 5가지의 학습 환경 평가

| Uber 비판 | 학습 환경 영향 | 평가 |
|---|---|---|
| ① Write amplification (MVCC + 인덱스 갱신) | billion-row + 광범위 인덱스에서 발현 | 본 환경 데이터 규모에서 비활성 |
| ② Cross-DC physical replication 대역폭 | 단일 노드 환경 | 무관 |
| ③ Connection-per-process | 1000 VU 부하에서 유효 | **유효 — 학습 토픽으로 활용** (HikariCP 튜닝, 후속 phase에서 PgBouncer 도입 가능) |
| ④ Buffer pool 관리 (kernel page cache 의존) | working set이 RAM에 들어감 | 미미 |
| ⑤ 9.2 corruption 버그 | 2026년 환경에서 해결 | 해당 없음 |

비판 5건 중 1건만 본 환경에서 활성이며, 그것조차 *학습 가치를 주는* 방향이다.

### 3. ADR-001과의 정합 점검

ADR-001은 "jOOQ는 SQL-first이므로 DB 중립" 같은 일반론으로 해석될 여지가 있으나, **현재 jOOQ codegen 설정은 PostgreSQL-specific**이다 (`build.gradle.kts`):

```
name = "org.jooq.codegen.KotlinGenerator"
database.apply { name = "org.jooq.meta.postgres.PostgresDatabase" }
```

DB를 바꾸려면 codegen 재설정 + 스키마 dialect 차이(ENUM 표현, JSONB, partition 문법) 흡수가 필요하다. 즉 "jOOQ가 양쪽을 지원한다"가 *zero-cost swap*을 의미하지는 않으며, ADR-001의 묵시적 전제(PostgreSQL 단일)를 ADR-004가 명시화한다.

### 4. 도메인 매핑

- `value class` ID 타입 → PostgreSQL `INT GENERATED ALWAYS AS IDENTITY`와 자연스럽게 정렬
- `sealed interface OrderStatus` → PostgreSQL `CREATE TYPE ... AS ENUM`로 가까운 표현 가능
- 후속 phase 후보(시계열 분석/집계) → PostgreSQL window function, CTE, materialized view, partitioning이 풍부

## Consequences

- Phase 0~1의 1차 관측 도구는 `psql` 직접 질의(`pg_stat_activity`, `pg_locks`, `pg_stat_statements`)로 고정
- 단일 노드 학습 환경에서는 Uber 비판 ①②④⑤이 발현되지 않는다는 사실을 *부정하지 않고 환경 한계로 인정*. 후속 phase에서 의도적으로 부하/데이터 규모를 키우면 ①이 부분 발현될 가능성은 있음
- DB 변경의 실비용은 jOOQ codegen 재설정 + dialect 차이 흡수. 후속 phase에서 의도적 비교 벤치를 위해 dual-DB 환경을 일시적으로 구성하는 선택지는 열어둠

## Considered Alternatives

- **MySQL/InnoDB**: Uber 비판 ③(connection 처리)과 ①(write amplification)에서 우위. 그러나 동시성 학습 도구(advisory lock, SKIP LOCKED 동작 차이)가 PostgreSQL 대비 빈약하며, 학습 환경에서 ①은 비활성. 학습 ROI 낮음.
- **SQLite/단일 파일**: 학습 초기 실험에 충분하다는 주장(news.hada.io/topic?id=28587)이 있으나, 본 프로젝트는 *다중 프로세스 동시 쓰기 + 트랜잭션 원자성*이 학습 주제 그 자체이므로 그 글의 분류상 "DB가 필요한 영역"에 해당한다.

