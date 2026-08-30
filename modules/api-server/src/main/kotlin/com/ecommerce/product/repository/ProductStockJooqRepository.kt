package com.ecommerce.product.repository

import com.ecommerce.jooq.tables.references.PRODUCTS
import com.ecommerce.product.domain.ProductId
import com.ecommerce.product.domain.ProductStockRepository
import org.jooq.DSLContext
import org.springframework.stereotype.Repository
import java.time.LocalDateTime

@Repository
class ProductStockJooqRepository(
    private val dsl: DSLContext
) : ProductStockRepository {
    override fun tryLockStock(id: ProductId, quantity: Int): Boolean {
        return dsl.selectOne()
            .from(PRODUCTS)
            .where(PRODUCTS.ID.eq(id.value.toInt()))
            .and(PRODUCTS.STOCK_QTY.ge(quantity))
            .forUpdate()
            .fetchOne() != null
    }

    override fun decrease(id: ProductId, quantity: Int) {
        require(quantity > 0) { "quantity must be positive: $quantity" }

        val updatedCount = dsl.update(PRODUCTS)
            .set(PRODUCTS.STOCK_QTY, PRODUCTS.STOCK_QTY - quantity)
            .set(PRODUCTS.UPDATED_AT, LocalDateTime.now())
            .where(PRODUCTS.ID.eq(id.value.toInt()))
            .execute()

        check(updatedCount == 1) {
            "Product stock was not updated: productId=${id.value}"
        }
    }
}
