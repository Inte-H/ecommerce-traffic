package com.ecommerce.order.application

import com.ecommerce.order.domain.NewOrder
import com.ecommerce.order.domain.OrderItem
import com.ecommerce.order.domain.OrderRepository
import com.ecommerce.product.domain.ProductRepository
import com.ecommerce.product.domain.ProductStockRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Transactional
@Service
open class PlaceOrderService(
    private val orderRepository: OrderRepository,
    private val productRepository: ProductRepository,
    private val productStockRepository: ProductStockRepository,
) {
    fun place(command: PlaceOrderCommand): PlaceOrderResult {
        val quantity = command.quantity
        val addressId = command.addressId

        require(quantity > 0) { "quantity must be positive: $quantity" }
        require(addressId > 0) { "addressId must be positive: $addressId" }

        val productId = command.productId
        val product = productRepository.findById(productId)
            ?: throw ProductNotFoundException(productId)

        if (!productStockRepository.tryLockStock(productId, quantity)) {
            throw InsufficientStockException(productId, quantity)
        }

        productStockRepository.decrease(productId, quantity)

        val newOrder = NewOrder(
            customerId = command.customerId,
            items = listOf(
                OrderItem(
                    productId = productId,
                    quantity = quantity,
                    unitPrice = product.effectivePrice,
                )
            )
        )

        val createdOrder = orderRepository.create(newOrder, addressId)

        return PlaceOrderResult(createdOrder.id)
    }
}