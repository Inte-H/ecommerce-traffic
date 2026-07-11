package com.ecommerce.product.repository

import com.ecommerce.jooq.tables.records.ProductsRecord
import com.ecommerce.product.domain.CategoryId
import com.ecommerce.product.domain.Product
import com.ecommerce.product.domain.ProductId
import com.ecommerce.sharedkernel.domain.Money

fun ProductsRecord.toDomain(): Product {
    return Product(
        id = ProductId(requireNotNull(this.id) { "products.id is required" }.toLong()),
        name = requireNotNull(this.name) { "products.name is required" },
        price = Money(requireNotNull(this.price) { "products.price is required" }.toLong()),
        discountedPrice = null,
        categoryId = CategoryId(
            requireNotNull(this.categoryId) { "products.category_id is required" }.toLong()
        ),
        description = this.description,
    )
}
