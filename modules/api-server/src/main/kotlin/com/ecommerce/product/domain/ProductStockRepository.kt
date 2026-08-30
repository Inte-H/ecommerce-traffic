package com.ecommerce.product.domain

interface ProductStockRepository {
    fun tryLockStock(id: ProductId, quantity: Int): Boolean
    fun decrease(id: ProductId, quantity: Int)
}