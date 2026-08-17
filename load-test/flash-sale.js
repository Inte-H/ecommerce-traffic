import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Trend } from 'k6/metrics';

// ─── Phase 0 — no-lock baseline 부하 시나리오 ────────────────────────────────
// 의도: 동시성 제어 없이 SELECT-check-UPDATE를 단일 endpoint에 동시에 때려
//       lost update / oversold / negative stock 을 측정 가능한 형태로 노출시킨다.
// 졸업 조건은 k6 결과가 아니라 부하 종료 후 SQL 측정으로 판정한다
// (측정 SQL 원본: docs/reports/phase-0.md "측정 SQL"):
//   - 부하 중 판매 수량(order_items 차분) − 초기 stock > 0  → oversold
//   - SELECT stock_qty FROM products WHERE id = ?            → 음수면 lost update 가시 증거
//
// 실행:
//   k6 run --env PRODUCT_ID=1 --env BASE_URL=http://localhost:8080 flash-sale.js

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const ORDER_PATH = __ENV.ORDER_PATH || '/api/orders/place';
const PRODUCT_ID = parseInt(__ENV.PRODUCT_ID || '1', 10);

const insufficientStock = new Counter('insufficient_stock'); // 서버가 거절한 횟수 (참고용)
const orderLatency = new Trend('order_latency', true);

// 409(재고 부족 거절)는 이 시나리오의 정상 응답이므로 http_req_failed 에 실패로 집계하지 않는다.
http.setResponseCallback(http.expectedStatuses(200, 201, 409));

export const options = {
    scenarios: {
        baseline: {
            executor: 'ramping-vus',
            startVUs: 0,
            stages: [
                { duration: '5s',  target: 100 },  // 워밍업
                { duration: '20s', target: 500 },  // 피크: 동시성 노출 구간
                { duration: '5s',  target: 0 },    // 쿨다운
            ],
        },
    },
    // Phase 0는 "동시성 결함을 측정"이 목적이라 통과/실패 임계는 두지 않는다.
    // 응답 시간과 처리량은 관찰 데이터로 보고서에 기록.
};

export default function () {
    const start = Date.now();

    const res = http.post(`${BASE_URL}${ORDER_PATH}`, JSON.stringify({
        customerId: Math.floor(Math.random() * 5000) + 1,
        productId: PRODUCT_ID,
        quantity: 1,
        addressId: Math.floor(Math.random() * 8000) + 1, // orders.address_id 는 FK 없음 — 시드 범위(1..8563) 내 임의값
    }), {
        headers: { 'Content-Type': 'application/json' },
        tags: { name: 'place_order' },
    });

    orderLatency.add(Date.now() - start);

    if (res.status === 409) insufficientStock.add(1);

    check(res, {
        'status is 200/201/409': (r) => r.status === 200 || r.status === 201 || r.status === 409,
    });

    sleep(0.1);
}

export function handleSummary(data) {
    const m = data.metrics;
    const total = m.http_reqs ? m.http_reqs.values.count : 0;
    const failed = m.http_req_failed ? m.http_req_failed.values.passes : 0;
    const rejected = m.insufficient_stock ? m.insufficient_stock.values.count : 0;
    const p95 = m.http_req_duration ? m.http_req_duration.values['p(95)'] : 0;
    const rps = m.http_reqs ? m.http_reqs.values.rate : 0;

    console.log('\n=== Phase 0 baseline (no-lock) ===');
    console.log(`Total requests:      ${total}`);
    console.log(`Accepted (2xx):      ${total - failed - rejected}`);
    console.log(`Insufficient stock:  ${rejected}  (409)`);
    console.log(`HTTP failures:       ${failed}  (5xx / 기타 — 200/201/409 제외)`);
    console.log(`p95 latency:         ${p95}ms`);
    console.log(`RPS:                 ${rps}`);
    console.log('\n→ 졸업 조건 판정은 psql로 직접 (oversold count, stock 음수 여부)');

    return { stdout: '' }; // 위 console.log로 출력
}
