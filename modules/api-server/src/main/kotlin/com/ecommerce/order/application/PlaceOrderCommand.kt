package com.ecommerce.order.application

import com.ecommerce.order.domain.CustomerId
import com.ecommerce.product.domain.ProductId

data class PlaceOrderCommand(
    val customerId: CustomerId,
    val productId: ProductId,
    val quantity: Int,
    val addressId: Long,
)

