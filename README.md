# ecommerce-traffic

Kotlin + Spring Boot 기반의 **단계적 학습 프로젝트**. 학습 주제는 **고동시성 트랜잭션 처리**이며, "가장 단순한 구조 → 부하 측정 → 문제점 식별 → 구조 개선"의 사이클을 반복한다.

이 프로젝트는 **production-ready 코드가 아니다**. 각 phase는 직전 phase에서 *측정으로 드러난* 문제를 해결하기 위한 최소 변화로 설계되어 있고, 의도적으로 결함을 노출시키는 단계도 포함된다.

## 학습 의도

- **Phase 0 (`phase-0/baseline-no-locking`)**: 동시성 제어를 *의도적으로* 빼서 race condition을 정량 측정. lost update / oversold 직접 관측이 목적이며, 이 단계의 코드를 production 기준으로 평가하지 않는다.
- **Phase 1 이후**: Phase 0의 측정 결과가 다음 phase의 동기부여가 된다. 어떤 동시성 제어를 도입할지는 측정 결과를 본 뒤 결정한다(미리 박지 않음).
- **모든 phase는 측정-주도 졸업 조건**을 가진다. 시간 박스나 산출물 완성도가 아니라, "다음 phase로 가는 정량 신호"가 충족되면 그때 다음으로 간다.

## 진행 방식

1. 새 phase 시작 시 별도 브랜치(`phase-N/<slug>`) 생성
2. Phase 시작 전: 졸업 조건(정량 신호 ≥ 2개)을 phase 보고서 상단에 명시
3. 구현 → k6 부하 → 측정 → 졸업 조건 충족 여부 판단
4. Phase 종료 시: `docs/reports/phase-N.md` 작성 (측정 결과 + 코틀린 기능 인덱스 + 다음 phase 동기부여)

## 관측 인프라

Phase 0~1은 의도적으로 경량으로 시작한다.

- **부하 발생기**: [k6](./load-test/) — 외부에서 본 응답 시간/RPS/에러율
- **시스템 내부 진단**: `psql`로 `pg_stat_activity` / `pg_locks` / `pg_stat_statements` 직접 조회
- **Prometheus + Micrometer + Grafana**: "수치만으로 원인을 못 짚는다"를 *직접 부딪힌* 시점에 독립 phase로 도입한다. 미리 깔지 않는다 — "왜 관측이 필요한가"를 학습 사이클 안에서 동기부여하기 위함.

## AI 위임 정책

이 프로젝트는 사수(멘토) 모드로 운영된다. 본체 학습 영역에서 AI는 **실제 코드 대신 의사코드/구조/아이디어**를 제공한다.

| 영역 | 정책 | 근거 |
|---|---|---|
| 동시성 전략 구현 (`OrderConcurrencyStrategies`) | **직접 작성** | 학습 주제 본체 |
| 코루틴 + Virtual Thread dispatcher 통합 | **직접 작성** | 학습 주제 본체 |
| jOOQ 쿼리 작성 | **직접 작성** | jOOQ 학습 |
| 도메인 모델 변경 | **직접 작성** | 모델링도 학습 |
| Phase 보고서 (측정 결과 해석) | **직접 작성** | 측정→가설 사이클이 학습 핵심 |
| 측정 SQL (`pg_stat_activity` 류) | AI 도움 OK | 도구 사용법, 외곽 |
| k6 시나리오 boilerplate 변형 | AI 도움 OK | 도구 사용법 |
| docker-compose / 마이그레이션 스크립트 | AI 도움 OK | 인프라, 외곽 |
| 본인 작성 코드 리뷰 | **AI에게 적극 받기** | "senior dev 관점에서 뭐가 안 좋은가?" |
| ADR / CONTEXT.md / README | AI와 협업 OK | 문서화는 학습의 압축 |

**보조 의례 — "베껴 쓰기 안 하기"**: 본체 영역에서 막혀서 AI에게 시범 코드를 받았다면, 그걸 그대로 두지 말고 *덮어두고 자기 손으로 다시 짜는다*. AI 코드는 참고서로 한 번 본 셈.

## 도메인 모델 현재 상태

- **사용 중**: `Product`, `Order` aggregate, `products.stock_qty` 단일 컬럼 차감 모델
- **휴면**: `Inventory` aggregate (reserve / release / commit 워크플로) — Saga 학습 phase에서 재도입 예정. 현재 phase에서는 사용하지 않음.

## 디렉터리 구조

```
docs/
├── adr/decisions.md       # 아키텍처 결정 기록 (ADR-001~)
└── reports/               # Phase 보고서 (phase-N.md)
infrastructure/docker/     # Postgres 컨테이너 + 스키마/시드
load-test/flash-sale.js    # k6 부하 시나리오
modules/api-server/        # Spring Boot + jOOQ + Kotlin 앱
seed-data/                 # 시드 데이터 생성 도구
CONTEXT.md                 # 도메인 용어집
```

## Phase 진행 상황

| Phase | 브랜치 | 상태 | 보고서 |
|---|---|---|---|
| 0 | `phase-0/baseline-no-locking` | 졸업 — 조건 2/2 충족 (oversold 19, stock -19) | [phase-0.md](./docs/reports/phase-0.md) — 섹션 3(코틀린 기능 인덱스)만 남음 |
| 1 | `phase-1/select-for-update` | 측정 완료 — 졸업 조건 2/2 충족 (oversold 0, stock 0) · 비용 rps −41%, p95 ×2.7 | [phase-1.md](./docs/reports/phase-1.md) — 측정 표 + 증거 기입, 해석·섹션 3·4 남음 |
