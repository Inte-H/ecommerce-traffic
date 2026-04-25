package com.ecommerce.product.domain

import com.ecommerce.order.domain.Money
import com.ecommerce.order.domain.ProductId
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test

class ProductTest {

    private fun sampleProduct(
        name: String = "테스트 상품",
        price: Money = Money(10000),
        discountedPrice: Money? = null,
        description: String? = null,
    ) = Product(
        id = ProductId(1L),
        name = name,
        price = price,
        discountedPrice = discountedPrice,
        categoryId = CategoryId(1L),
        description = description,
    )

    @Test
    fun `Product 생성 시 모든 필드가 보존된다`() {
        val product = Product(
            id = ProductId(42L),
            name = "스마트폰",
            price = Money(1_000_000),
            discountedPrice = Money(800_000),
            categoryId = CategoryId(10L),
            description = "최신형 스마트폰",
        )

        assertThat(product.id).isEqualTo(ProductId(42L))
        assertThat(product.name).isEqualTo("스마트폰")
        assertThat(product.price).isEqualTo(Money(1_000_000))
        assertThat(product.discountedPrice).isEqualTo(Money(800_000))
        assertThat(product.categoryId).isEqualTo(CategoryId(10L))
        assertThat(product.description).isEqualTo("최신형 스마트폰")
    }

    @Test
    fun `name 이 공백이면 IllegalArgumentException`() {
        assertThatThrownBy { sampleProduct(name = "   ") }
            .isInstanceOf(IllegalArgumentException::class.java)
            .hasMessageContaining("상품명은 비어있을 수 없습니다")
    }

    @Test
    fun `name 이 200자 초과면 IllegalArgumentException`() {
        val longName = "가".repeat(201)
        assertThatThrownBy { sampleProduct(name = longName) }
            .isInstanceOf(IllegalArgumentException::class.java)
            .hasMessageContaining("상품명은 200자 이하여야 합니다")
    }

    @Test
    fun `discountedPrice 가 price 와 같으면 IllegalArgumentException`() {
        assertThatThrownBy { sampleProduct(price = Money(10000), discountedPrice = Money(10000)) }
            .isInstanceOf(IllegalArgumentException::class.java)
            .hasMessageContaining("할인가는 정가보다 낮아야 합니다")
    }

    @Test
    fun `discountedPrice 가 price 보다 크면 IllegalArgumentException`() {
        assertThatThrownBy { sampleProduct(price = Money(10000), discountedPrice = Money(15000)) }
            .isInstanceOf(IllegalArgumentException::class.java)
            .hasMessageContaining("할인가는 정가보다 낮아야 합니다")
    }

    @Test
    fun `discountedPrice 가 null 이면 effectivePrice 는 price`() {
        val product = sampleProduct(price = Money(10000), discountedPrice = null)
        assertThat(product.effectivePrice).isEqualTo(Money(10000))
    }

    @Test
    fun `discountedPrice 가 있으면 effectivePrice 는 discountedPrice`() {
        val product = sampleProduct(price = Money(10000), discountedPrice = Money(7000))
        assertThat(product.effectivePrice).isEqualTo(Money(7000))
    }

    @Test
    fun `description 은 null 이어도 생성된다`() {
        val product = sampleProduct(description = null)
        assertThat(product.description).isNull()
    }

    @Test
    fun `discountPercent 는 할인 없으면 0`() {
        val product = sampleProduct(price = Money(10000), discountedPrice = null)
        assertThat(product.discountPercent).isEqualTo(0)
    }

    @Test
    fun `discountPercent 는 정가 10000원 할인가 7000원이면 30`() {
        val product = sampleProduct(price = Money(10000), discountedPrice = Money(7000))
        assertThat(product.discountPercent).isEqualTo(30)
    }
}
