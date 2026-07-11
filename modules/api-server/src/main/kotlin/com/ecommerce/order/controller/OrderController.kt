package com.ecommerce.order.controller

import com.ecommerce.order.application.PlaceOrderCommand
import com.ecommerce.order.application.PlaceOrderService
import com.ecommerce.order.domain.CustomerId
import com.ecommerce.product.domain.ProductId
import org.springframework.http.HttpStatus
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.ResponseStatus
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/orders")
class OrderController(
    private val placeOrderService: PlaceOrderService,
) {
    @PostMapping("/place")
    @ResponseStatus(HttpStatus.CREATED)
    fun place(@RequestBody request: PlaceOrderRequest): PlaceOrderResponse {
        val result = placeOrderService.place(request.toCommand())
        return PlaceOrderResponse(orderId = result.orderId.value)
    }
}

data class PlaceOrderRequest(
    val customerId: Long,
    val productId: Long,
    val quantity: Int,
    val addressId: Long,
) {
    fun toCommand(): PlaceOrderCommand {
        return PlaceOrderCommand(
            customerId = CustomerId(customerId),
            productId = ProductId(productId),
            quantity = quantity,
            addressId = addressId,
        )
    }
}

data class PlaceOrderResponse(
    val orderId: Long,
)
