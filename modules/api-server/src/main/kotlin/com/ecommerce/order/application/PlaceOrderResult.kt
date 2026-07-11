package com.ecommerce.order.application

import com.ecommerce.order.domain.OrderId

data class PlaceOrderResult(
    val orderId: OrderId,
)
