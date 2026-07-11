package com.ecommerce.product.domain

interface ProductStockRepository {
    fun findStock(id: ProductId): Int?
    fun decrease(id: ProductId, quantity: Int)
}