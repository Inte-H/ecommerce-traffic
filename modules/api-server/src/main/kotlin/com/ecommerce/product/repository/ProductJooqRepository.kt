package com.ecommerce.product.repository

import com.ecommerce.jooq.tables.references.PRODUCTS
import com.ecommerce.product.domain.Product
import com.ecommerce.product.domain.ProductId
import com.ecommerce.product.domain.ProductRepository
import org.jooq.DSLContext
import org.springframework.stereotype.Repository

@Repository
class ProductJooqRepository(
    private val dsl: DSLContext,
) : ProductRepository {
    override fun findById(id: ProductId): Product? {
        return dsl.selectFrom(PRODUCTS)
            .where(PRODUCTS.ID.eq(id.value.toInt()))
            .fetchOne()
            ?.toDomain()
    }
}
