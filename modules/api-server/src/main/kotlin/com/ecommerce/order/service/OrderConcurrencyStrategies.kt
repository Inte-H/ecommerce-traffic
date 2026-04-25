package com.ecommerce.order.service

import com.ecommerce.order.domain.*
import org.jooq.DSLContext
import org.redisson.api.RedissonClient
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.util.concurrent.TimeUnit

/**
 * 4가지 동시성 제어 전략 비교
 *
 * Phase 2 핵심: Flash Sale 시나리오 (재고 10개 → 1000명 동시 주문)
 * k6 부하 테스트로 TPS, 재고 정합성, 응답 시간을 각 방식별 비교
 */

// ─── 1. Pessimistic Lock (비관적 락) ─────────────────────────────────────────
@Service
class PessimisticLockOrderService(private val dsl: DSLContext) {

    @Transactional
    fun placeOrder(command: PlaceOrderCommand): OrderId {
        // SELECT ... FOR UPDATE → 다른 트랜잭션 대기
        val stock = dsl.fetchOne(
            """
            SELECT stock_quantity FROM inventory_transactions
            WHERE product_id = ?
            FOR UPDATE  -- 행 잠금
            """,
            command.productId.value
        )?.get(0, Int::class.java) ?: 0

        check(stock >= command.quantity) { "재고 부족" }

        // 재고 차감 + 주문 생성 (같은 트랜잭션)
        dsl.execute(
            "UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?",
            command.quantity, command.productId.value
        )
        return saveOrder(command)
    }

    private fun saveOrder(command: PlaceOrderCommand): OrderId = OrderId(1L) // stub
}

// ─── 2. Optimistic Lock (낙관적 락) ──────────────────────────────────────────
@Service
class OptimisticLockOrderService(private val dsl: DSLContext) {

    @Transactional
    fun placeOrder(command: PlaceOrderCommand): OrderId {
        repeat(3) { attempt ->
            val record = dsl.fetchOne(
                "SELECT stock_quantity, version FROM products WHERE id = ?",
                command.productId.value
            ) ?: error("상품 없음")

            val stock = record.get(0, Int::class.java)
            val version = record.get(1, Int::class.java)

            check(stock >= command.quantity) { "재고 부족" }

            // version 조건부 UPDATE → 충돌 감지
            val updated = dsl.execute(
                "UPDATE products SET stock_quantity = stock_quantity - ?, version = version + 1 WHERE id = ? AND version = ?",
                command.quantity, command.productId.value, version
            )

            if (updated > 0) return saveOrder(command)
            // 충돌 시 재시도 (최대 3회)
            if (attempt == 2) error("재고 변경 충돌 - 재시도 초과")
        }
        error("주문 처리 실패")
    }

    private fun saveOrder(command: PlaceOrderCommand): OrderId = OrderId(1L) // stub
}

// ─── 3. Redis 분산 락 ────────────────────────────────────────────────────────
@Service
class RedisLockOrderService(
    private val dsl: DSLContext,
    private val redisson: RedissonClient,
) {

    @Transactional
    fun placeOrder(command: PlaceOrderCommand): OrderId {
        val lockKey = "inventory:lock:${command.productId.value}"
        val lock = redisson.getLock(lockKey)

        // 최대 3초 대기, 5초 후 자동 해제
        val acquired = lock.tryLock(3, 5, TimeUnit.SECONDS)
        check(acquired) { "락 획득 실패 - 서버 과부하" }

        try {
            val stock = dsl.fetchOne(
                "SELECT stock_quantity FROM products WHERE id = ?",
                command.productId.value
            )?.get(0, Int::class.java) ?: 0

            check(stock >= command.quantity) { "재고 부족" }

            dsl.execute(
                "UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?",
                command.quantity, command.productId.value
            )
            return saveOrder(command)
        } finally {
            lock.unlock()
        }
    }

    private fun saveOrder(command: PlaceOrderCommand): OrderId = OrderId(1L) // stub
}

// ─── 4. Redis 재고 선차감 (가장 고성능) ──────────────────────────────────────
@Service
class RedisStockOrderService(
    private val dsl: DSLContext,
    private val redisTemplate: org.springframework.data.redis.core.StringRedisTemplate,
) {

    // 서비스 시작 시 Redis에 재고 동기화 필요 (생략)
    // @Transactional: placeOrder 자체에 선언 — private 메서드에 선언하면 Spring 프록시가
    // 인터셉트하지 못해 트랜잭션이 묵시적으로 무시되는 버그를 방지
    @Transactional
    fun placeOrder(command: PlaceOrderCommand): OrderId {
        val stockKey = "inventory:stock:${command.productId.value}"

        // Redis DECRBY → 원자적 감소 (O(1) 성능)
        val remaining = redisTemplate.opsForValue()
            .decrement(stockKey, command.quantity.toLong())
            ?: error("재고 정보 없음")

        // 재고 초과 시 복구
        if (remaining < 0) {
            redisTemplate.opsForValue().increment(stockKey, command.quantity.toLong())
            error("재고 부족 (선차감)")
        }

        // 비동기로 DB 반영 (Kafka 이벤트로 전달)
        // eventPublisher.publish(StockDecreasedEvent(command.productId, command.quantity))
        return OrderId(1L) // stub
    }
}

// ─── Command ─────────────────────────────────────────────────────────────────
data class PlaceOrderCommand(
    val customerId: CustomerId,
    val productId: ProductId,
    val quantity: Int,
)
