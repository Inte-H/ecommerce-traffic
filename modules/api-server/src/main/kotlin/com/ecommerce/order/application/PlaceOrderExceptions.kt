package com.ecommerce.order.application

import com.ecommerce.product.domain.ProductId

class ProductNotFoundException(
    productId: ProductId,
) : RuntimeException("Product not found: productId=${productId.value}")

class InsufficientStockException(
    productId: ProductId,
    requested: Int,
    available: Int,
) : RuntimeException(
    "Insufficient stock: productId=${productId.value}, requested=$requested, available=$available"
)
