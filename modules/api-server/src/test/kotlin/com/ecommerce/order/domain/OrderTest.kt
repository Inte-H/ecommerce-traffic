package com.ecommerce.order.domain

import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test

class OrderTest {

    // ─── 테스트용 헬퍼 빌더 ────────────────────────────────────────────────────

    private fun sampleItem(
        productId: Long = 1L,
        quantity: Int = 2,
        unitPrice: Long = 1000L,
    ) = OrderItem(
        productId = ProductId(productId),
        quantity = quantity,
        unitPrice = Money(unitPrice),
    )

    private fun sampleOrder(
        id: Long = 1L,
        customerId: Long = 100L,
        items: List<OrderItem> = listOf(sampleItem()),
    ) = Order.create(
        id = OrderId(id),
        customerId = CustomerId(customerId),
        items = items,
    )

    // ─── 주문 생성 ─────────────────────────────────────────────────────────────

    @Test
    fun `주문 생성 시 OrderCreatedEvent 가 발행된다`() {
        val order = sampleOrder()

        assertThat(order.events).hasSize(1)
        assertThat(order.events[0]).isInstanceOf(OrderCreatedEvent::class.java)
        val event = order.events[0] as OrderCreatedEvent
        assertThat(event.orderId).isEqualTo(OrderId(1L))
        assertThat(event.customerId).isEqualTo(CustomerId(100L))
    }

    @Test
    fun `빈 항목 리스트로 주문 생성 시 IllegalArgumentException`() {
        assertThatThrownBy { sampleOrder(items = emptyList()) }
            .isInstanceOf(IllegalArgumentException::class.java)
            .hasMessageContaining("주문 항목이 비어있습니다")
    }

    @Test
    fun `21개 이상 항목으로 주문 시 IllegalArgumentException`() {
        val items = (1..21).map { sampleItem(productId = it.toLong()) }
        assertThatThrownBy { sampleOrder(items = items) }
            .isInstanceOf(IllegalArgumentException::class.java)
            .hasMessageContaining("최대 20종류")
    }

    @Test
    fun `합계는 모든 항목 subtotal 의 합이다`() {
        val items = listOf(
            sampleItem(productId = 1L, quantity = 2, unitPrice = 1000L), // 2000
            sampleItem(productId = 2L, quantity = 3, unitPrice = 500L),  // 1500
        )
        val order = sampleOrder(items = items)

        assertThat(order.total).isEqualTo(Money(3500L))
    }

    // ─── markAsPaid ────────────────────────────────────────────────────────────

    @Test
    fun `Created 상태의 주문은 markAsPaid 가능하다`() {
        val order = sampleOrder()

        order.markAsPaid()

        assertThat(order.status).isEqualTo(OrderStatus.Paid)
    }

    @Test
    fun `Paid 상태에서 markAsPaid 호출 시 IllegalStateException`() {
        val order = sampleOrder()
        order.markAsPaid()

        assertThatThrownBy { order.markAsPaid() }
            .isInstanceOf(IllegalStateException::class.java)
            .hasMessageContaining("결제할 수 없는 주문 상태입니다")
    }

    // ─── cancel ────────────────────────────────────────────────────────────────

    @Test
    fun `Created 상태의 주문은 cancel 가능하다`() {
        val order = sampleOrder()

        order.cancel("고객 요청")

        assertThat(order.status).isInstanceOf(OrderStatus.Cancelled::class.java)
    }

    @Test
    fun `Paid 상태의 주문은 cancel 가능하다`() {
        val order = sampleOrder()
        order.markAsPaid()

        order.cancel("환불 요청")

        assertThat(order.status).isInstanceOf(OrderStatus.Cancelled::class.java)
    }

    @Test
    fun `Cancelled 상태의 주문은 cancel 시 IllegalStateException`() {
        val order = sampleOrder()
        order.cancel("첫 번째 취소")

        assertThatThrownBy { order.cancel("두 번째 취소") }
            .isInstanceOf(IllegalStateException::class.java)
            .hasMessageContaining("취소할 수 없는 주문 상태입니다")
    }

    // ─── 이벤트 발행 ───────────────────────────────────────────────────────────

    @Test
    fun `markAsPaid 호출 시 OrderPaidEvent 발행 후 상태가 Paid 로 전이`() {
        val items = listOf(sampleItem(quantity = 2, unitPrice = 1000L))
        val order = sampleOrder(items = items)
        order.clearEvents() // OrderCreatedEvent 제거 후 Paid 이벤트만 검증

        order.markAsPaid()

        assertThat(order.status).isEqualTo(OrderStatus.Paid)
        assertThat(order.events).hasSize(1)
        val event = order.events[0] as OrderPaidEvent
        assertThat(event.orderId).isEqualTo(OrderId(1L))
        assertThat(event.amount).isEqualTo(Money(2000L))
    }

    @Test
    fun `cancel 호출 시 OrderCancelledEvent 발행 후 상태가 Cancelled 로 전이`() {
        val order = sampleOrder()
        order.clearEvents() // OrderCreatedEvent 제거 후 Cancelled 이벤트만 검증

        order.cancel("재고 없음")

        assertThat(order.status).isInstanceOf(OrderStatus.Cancelled::class.java)
        assertThat(order.events).hasSize(1)
        val event = order.events[0] as OrderCancelledEvent
        assertThat(event.orderId).isEqualTo(OrderId(1L))
        assertThat(event.reason).isEqualTo("재고 없음")
    }

    // ─── clearEvents / events ─────────────────────────────────────────────────

    @Test
    fun `clearEvents 호출 후 events 는 비어있다`() {
        val order = sampleOrder() // OrderCreatedEvent 1개 존재

        order.clearEvents()

        assertThat(order.events).isEmpty()
    }

    // ─── OrderItem 유효성 ─────────────────────────────────────────────────────

    @Test
    fun `OrderItem 수량 0 이하면 IllegalArgumentException`() {
        assertThatThrownBy { sampleItem(quantity = 0) }
            .isInstanceOf(IllegalArgumentException::class.java)
            .hasMessageContaining("수량은 1개 이상이어야 합니다")
    }

    @Test
    fun `OrderItem 수량 100 초과면 IllegalArgumentException`() {
        assertThatThrownBy { sampleItem(quantity = 101) }
            .isInstanceOf(IllegalArgumentException::class.java)
            .hasMessageContaining("단일 상품 최대 주문 수량은 100개입니다")
    }

    // ─── Money 유효성 ─────────────────────────────────────────────────────────

    @Test
    fun `Money 음수 생성 시 IllegalArgumentException`() {
        assertThatThrownBy { Money(-1L) }
            .isInstanceOf(IllegalArgumentException::class.java)
            .hasMessageContaining("금액은 0 이상이어야 합니다")
    }
}
