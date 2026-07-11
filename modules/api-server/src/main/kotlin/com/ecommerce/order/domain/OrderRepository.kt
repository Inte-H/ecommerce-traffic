package com.ecommerce.order.domain

interface OrderRepository {
    fun create(order: NewOrder, addressId: Long): Order
    fun findById(id: OrderId): Order?
    fun updateStatus(order: Order): Order
}