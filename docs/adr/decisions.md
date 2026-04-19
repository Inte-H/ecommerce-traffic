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
