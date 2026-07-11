package com.ecommerce.order.repository

import com.ecommerce.jooq.tables.references.ORDERS
import com.ecommerce.jooq.tables.references.ORDER_ITEMS
import com.ecommerce.order.domain.*
import org.jooq.DSLContext
import org.springframework.stereotype.Repository
import java.time.LocalDateTime
import java.time.ZoneId

@Repository
class OrderJooqRepository(
    private val dsl: DSLContext,
) : OrderRepository {
    override fun create(order: NewOrder, addressId: Long): Order {
        val createdOrder = dsl.insertInto(ORDERS)
            .set(order.toInsertRecord(addressId))
            .returning()
            .fetchOne()
            ?: error("Failed to create order for customer: ${order.customerId.value}")
        val savedOrderId = requireNotNull(createdOrder.id) { "orders.id is required" }

        val itemRecords = order.items.map { item ->
            item.toRecord(savedOrderId.toLong())
        }

        if (itemRecords.isNotEmpty()) {
            dsl.batchInsert(itemRecords).execute()
        }

        return createdOrder.toDomain(order.items)
    }

    override fun findById(id: OrderId): Order? {
        val orderRecord = dsl.selectFrom(ORDERS)
            .where(ORDERS.ID.eq(id.value.toInt()))
            .fetchOne()
            ?: return null

        val itemRecords = dsl.selectFrom(ORDER_ITEMS)
            .where(ORDER_ITEMS.ORDER_ID.eq(id.value.toInt()))
            .orderBy(ORDER_ITEMS.ID.asc())
            .fetch()

        return orderRecord.toDomain(itemRecords.map { it.toDomain() })
    }

    override fun updateStatus(order: Order): Order {
        val cancelled = order.status as? OrderStatus.Cancelled

        val updatedCount = dsl.update(ORDERS)
            .set(ORDERS.STATUS, order.status.toJooq())
            .set(
                ORDERS.CANCELLED_AT,
                cancelled?.cancelledAt
                    ?.atZone(ZoneId.systemDefault())
                    ?.toLocalDateTime()
            )
            .set(ORDERS.NOTES, cancelled?.reason)
            .set(ORDERS.UPDATED_AT, LocalDateTime.now())
            .where(ORDERS.ID.eq(order.id.value.toInt()))
            .execute()

        check(updatedCount == 1) {
            "Order not found or not uniquely updated: ${order.id.value}"
        }

        return order
    }
}
