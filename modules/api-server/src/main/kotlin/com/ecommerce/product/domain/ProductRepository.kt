package com.ecommerce.product.domain

interface ProductRepository {
    fun findById(id: ProductId): Product?
    fun findByCategoryId(categoryId: CategoryId): List<Product>
}
