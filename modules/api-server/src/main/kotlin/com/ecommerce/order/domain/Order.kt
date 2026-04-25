package com.ecommerce.order.domain

import java.time.Instant

// ─── Value Objects ───────────────────────────────────────────────────────────
// value class: 런타임 오버헤드 없이 ID 타입을 구분 → 타입 혼동 방지 (컴파일 에러)
@JvmInline value class OrderId(val value: Long)
@JvmInline value class CustomerId(val value: Long)
@JvmInline value class ProductId(val value: Long)

// 금액: 음수 불허, 연산 오버로딩
@JvmInline value class Money(val amount: Long) {
    init { require(amount >= 0) { "금액은 0 이상이어야 합니다: $amount" } }
    operator fun plus(other: Money) = Money(amount + other.amount)
    operator fun minus(other: Money): Money {
        require(amount >= other.amount) { "잔액이 부족합니다" }
        return Money(amount - other.amount)
    }
}

// ─── Order Status (sealed interface) ─────────────────────────────────────────
// sealed interface: 주문 상태 전이를 컴파일 타임에 강제
// when 절에서 모든 케이스를 처리하지 않으면 컴파일 에러
sealed interface OrderStatus {
    data object Created : OrderStatus
    data object Paid : OrderStatus
    data object Preparing : OrderStatus
    data object Shipped : OrderStatus
    data class Cancelled(val reason: String, val cancelledAt: Instant) : OrderStatus

    fun canCancel(): Boolean = this is Created || this is Paid
    fun canPay(): Boolean = this is Created
}

// ─── Domain Events ───────────────────────────────────────────────────────────
sealed interface OrderEvent
data class OrderCreatedEvent(val orderId: OrderId, val customerId: CustomerId) : OrderEvent
data class OrderCancelledEvent(val orderId: OrderId, val reason: String) : OrderEvent
data class OrderPaidEvent(val orderId: OrderId, val amount: Money) : OrderEvent

// ─── Order Item ───────────────────────────────────────────────────────────────
data class OrderItem(
    val productId: ProductId,
    val quantity: Int,
    val unitPrice: Money,
) {
    init {
        require(quantity > 0) { "수량은 1개 이상이어야 합니다" }
        require(quantity <= 100) { "단일 상품 최대 주문 수량은 100개입니다" }
    }
    val subtotal: Money get() = Money(unitPrice.amount * quantity)
}

// ─── Order (Aggregate Root) ────────────────────────────────────────────────────
class Order private constructor(
    val id: OrderId,
    val customerId: CustomerId,
    private val _items: MutableList<OrderItem>,
    private var _status: OrderStatus,
    val createdAt: Instant,
) {
    val items: List<OrderItem> get() = _items.toList()
    val status: OrderStatus get() = _status
    val total: Money get() = _items.fold(Money(0)) { acc, item -> acc + item.subtotal }

    // 도메인 이벤트 수집 (명시적 발행)
    private val _events: MutableList<OrderEvent> = mutableListOf()

    // CQS: 읽기 전용 (이벤트 목록 조회)
    val events: List<OrderEvent> get() = _events.toList()

    // CQS: 커맨드 (이벤트 목록 초기화)
    fun clearEvents() { _events.clear() }

    // 비즈니스 규칙: 주문 취소
    fun cancel(reason: String) {
        check(_status.canCancel()) {
            "취소할 수 없는 주문 상태입니다: ${_status::class.simpleName}"
        }
        _status = OrderStatus.Cancelled(reason, Instant.now())
        _events.add(OrderCancelledEvent(id, reason))
    }

    // 비즈니스 규칙: 결제 완료 처리
    fun markAsPaid() {
        check(_status.canPay()) {
            "결제할 수 없는 주문 상태입니다: ${_status::class.simpleName}"
        }
        _status = OrderStatus.Paid
        _events.add(OrderPaidEvent(id, total))
    }

    companion object {
        // 팩토리 메서드: 주문 생성 규칙을 한 곳에서 관리
        fun create(
            id: OrderId,
            customerId: CustomerId,
            items: List<OrderItem>,
        ): Order {
            require(items.isNotEmpty()) { "주문 항목이 비어있습니다" }
            require(items.size <= 20) { "한 번에 최대 20종류의 상품을 주문할 수 있습니다" }

            val order = Order(
                id = id,
                customerId = customerId,
                _items = items.toMutableList(),
                _status = OrderStatus.Created,
                createdAt = Instant.now(),
            )
            order._events.add(OrderCreatedEvent(id, customerId))
            return order
        }
    }
}
