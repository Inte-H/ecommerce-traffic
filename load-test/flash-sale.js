import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

// ─── 시나리오: Flash Sale (한정 재고 동시 주문) ──────────────────────────────
// 실행: k6 run --env STRATEGY=pessimistic flash-sale.js
// 전략: pessimistic | optimistic | redis-lock | redis-stock

const STRATEGY = __ENV.STRATEGY || 'pessimistic';
const BASE_URL = 'http://localhost:8080';
const PRODUCT_ID = 1; // 재고 10개인 플래시 세일 상품

// 커스텀 메트릭
const stockErrors = new Counter('stock_errors');    // 재고 부족 에러 수
const concurrencyErrors = new Counter('concurrency_errors'); // 락 충돌 에러 수
const orderLatency = new Trend('order_latency', true);

export const options = {
    scenarios: {
        flash_sale: {
            executor: 'ramping-vus',
            startVUs: 0,
            stages: [
                { duration: '10s', target: 100 },   // 워밍업
                { duration: '20s', target: 1000 },  // 피크: 1000명 동시 요청
                { duration: '10s', target: 0 },     // 쿨다운
            ],
        },
    },
    thresholds: {
        http_req_duration: ['p(95)<2000'],  // 95% 요청이 2초 이내
        http_req_failed: ['rate<0.5'],      // 실패율 50% 미만 (재고 소진 당연)
    },
};

export default function () {
    const start = Date.now();

    const res = http.post(`${BASE_URL}/api/orders/${STRATEGY}`, JSON.stringify({
        customerId: Math.floor(Math.random() * 5000) + 1,
        productId: PRODUCT_ID,
        quantity: 1,
    }), {
        headers: { 'Content-Type': 'application/json' },
    });

    orderLatency.add(Date.now() - start);

    if (res.status === 409) stockErrors.add(1);       // 재고 부족
    if (res.status === 429) concurrencyErrors.add(1); // 락 충돌

    check(res, {
        'status is 200 or 409': (r) => r.status === 200 || r.status === 409,
    });

    sleep(0.1);
}

export function handleSummary(data) {
    // 결과 요약 출력 (벤치마크 리포트용)
    console.log(`\n=== Flash Sale Benchmark: ${STRATEGY} ===`);
    console.log(`Total requests: ${data.metrics.http_reqs.values.count}`);
    console.log(`Success (200):  ${data.metrics.http_reqs.values.count - stockErrors.value - data.metrics.http_req_failed.values.count}`);
    console.log(`Stock errors:   ${stockErrors.value}`);
    console.log(`p95 latency:    ${data.metrics.http_req_duration.values['p(95)']}ms`);
    console.log(`RPS:            ${data.metrics.http_reqs.values.rate}`);
}
