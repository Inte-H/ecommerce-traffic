package com.ecommerce.product.domain

interface ProductRepository {
    fun findById(id: ProductId): Product?
}
