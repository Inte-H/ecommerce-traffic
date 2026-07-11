package com.ecommerce.order.repository

import com.ecommerce.jooq.tables.records.OrderItemsRecord
import com.ecommerce.jooq.tables.records.OrdersRecord
import com.ecommerce.order.domain.*
import com.ecommerce.product.domain.ProductId
import com.ecommerce.sharedkernel.domain.Money
import java.time.LocalDateTime
import java.time.ZoneId
import com.ecommerce.jooq.enums.OrderStatus as JooqOrderStatus
import com.ecommerce.order.domain.OrderStatus as DomainOrderStatus

// ─── Order Item Mapper ────────────────────────────────────────

fun OrderItemsRecord.toDomain(): OrderItem {
    return OrderItem(
        productId = ProductId(requireNotNull(this.productId) { "order_items.product_id is required" }
            .toLong()),
        quantity = requireNotNull(this.quantity) { "order_items.quantity is required" },
        unitPrice = Money(requireNotNull(this.unitPrice) { "order_items.unit_price is required" }
            .toLong())
    )
}

fun OrderItem.toRecord(orderId: Long): OrderItemsRecord {
    return OrderItemsRecord().apply {
        this.orderId = orderId.toInt()
        this.productId = this@toRecord.productId.value.toInt()
        this.quantity = this@toRecord.quantity
        this.unitPrice = this@toRecord.unitPrice.amount.toBigDecimal()
        this.discountAmount = 0.toBigDecimal()
        this.subtotal = this@toRecord.subtotal.amount.toBigDecimal()
    }
}

// ─── Order Status Mapper ──────────────────────────────────────

fun JooqOrderStatus.toDomain(notes: String?, cancelledAt: LocalDateTime?): DomainOrderStatus {
    return when (this) {
        JooqOrderStatus.pending -> DomainOrderStatus.Created
        JooqOrderStatus.paid -> DomainOrderStatus.Paid
        JooqOrderStatus.preparing -> DomainOrderStatus.Preparing
        JooqOrderStatus.shipped -> DomainOrderStatus.Shipped
        JooqOrderStatus.cancelled -> DomainOrderStatus.Cancelled(
            reason = notes ?: "",
            cancelledAt = requireNotNull(cancelledAt) {
                "orders.cancelled_at is required when status is cancelled"
            }
                .atZone(ZoneId.systemDefault())
                .toInstant()
        )
        // 필요 시 스키마 정의된 상태들을 추가 매핑합니다.
        else -> DomainOrderStatus.Created
    }
}

fun DomainOrderStatus.toJooq(): JooqOrderStatus {
    return when (this) {
        is DomainOrderStatus.Created -> JooqOrderStatus.pending
        is DomainOrderStatus.Paid -> JooqOrderStatus.paid
        is DomainOrderStatus.Preparing -> JooqOrderStatus.preparing
        is DomainOrderStatus.Shipped -> JooqOrderStatus.shipped
        is DomainOrderStatus.Cancelled -> JooqOrderStatus.cancelled
    }
}

// ─── Order Mapper ─────────────────────────────────────────────

fun OrdersRecord.toDomain(items: List<OrderItem>): Order {
    return Order.reconstitute(
        id = OrderId(requireNotNull(this.id) { "orders.id is required" }.toLong()),
        customerId = CustomerId(requireNotNull(this.customerId) { "orders.customer_id is required" }
            .toLong()),
        items = items,
        status = requireNotNull(this.status) { "orders.status is required" }
            .toDomain(this.notes, this.cancelledAt),
        createdAt = requireNotNull(this.createdAt) { "orders.created_at is required" }
            .atZone(ZoneId.systemDefault())
            .toInstant()
    )
}

fun NewOrder.toInsertRecord(addressId: Long): OrdersRecord {
    val createdAt = this.createdAt
        .atZone(ZoneId.systemDefault())
        .toLocalDateTime()

    return OrdersRecord().apply {
        orderNumber = "ORD-${System.nanoTime()}"
        customerId = this@toInsertRecord.customerId.value.toInt()
        this.addressId = addressId.toInt()
        status = DomainOrderStatus.Created.toJooq()
        totalAmount = this@toInsertRecord.total.amount.toBigDecimal()
        discountAmount = 0.toBigDecimal()
        shippingFee = 0.toBigDecimal()
        pointUsed = 0
        pointEarned = 0
        orderedAt = createdAt
        this.createdAt = createdAt
        updatedAt = LocalDateTime.now()
    }
}
