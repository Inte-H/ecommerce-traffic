package com.ecommerce.inventory.domain

import com.ecommerce.order.domain.ProductId
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test

class InventoryTest {

    private val productId = ProductId(1L)

    @Test
    fun `초기 재고가 음수면 IllegalArgumentException`() {
        assertThatThrownBy { Inventory.create(productId, -1) }
            .isInstanceOf(IllegalArgumentException::class.java)
            .hasMessageContaining("초기 재고는 0 이상이어야 합니다")
    }

    @Test
    fun `생성 직후 reserved 는 0 이고 available 은 stockQuantity 와 같다`() {
        val inventory = Inventory.create(productId, 100)

        assertThat(inventory.reserved).isEqualTo(0)
        assertThat(inventory.available).isEqualTo(inventory.stockQuantity)
        assertThat(inventory.available).isEqualTo(100)
    }

    @Test
    fun `reserve 호출 시 reserved 증가 후 StockReservedEvent 발행`() {
        val inventory = Inventory.create(productId, 100)

        inventory.reserve(10)

        assertThat(inventory.reserved).isEqualTo(10)
        assertThat(inventory.available).isEqualTo(90)
        assertThat(inventory.events).hasSize(1)
        assertThat(inventory.events[0]).isEqualTo(StockReservedEvent(productId, 10))
    }

    @Test
    fun `reserve 가 가용 재고를 초과하면 IllegalStateException`() {
        val inventory = Inventory.create(productId, 5)

        assertThatThrownBy { inventory.reserve(6) }
            .isInstanceOf(IllegalStateException::class.java)
            .hasMessageContaining("가용 재고 부족")
    }

    @Test
    fun `reserve 수량이 0 이하면 IllegalArgumentException`() {
        val inventory = Inventory.create(productId, 100)

        assertThatThrownBy { inventory.reserve(0) }
            .isInstanceOf(IllegalArgumentException::class.java)
            .hasMessageContaining("예약 수량은 1 이상이어야 합니다")

        assertThatThrownBy { inventory.reserve(-1) }
            .isInstanceOf(IllegalArgumentException::class.java)
            .hasMessageContaining("예약 수량은 1 이상이어야 합니다")
    }

    @Test
    fun `release 호출 시 reserved 감소 후 StockReleasedEvent 발행`() {
        val inventory = Inventory.create(productId, 100)
        inventory.reserve(10)
        inventory.clearEvents()

        inventory.release(5)

        assertThat(inventory.reserved).isEqualTo(5)
        assertThat(inventory.available).isEqualTo(95)
        assertThat(inventory.events).hasSize(1)
        assertThat(inventory.events[0]).isEqualTo(StockReleasedEvent(productId, 5))
    }

    @Test
    fun `release 수량이 reserved 를 초과하면 IllegalArgumentException`() {
        val inventory = Inventory.create(productId, 100)
        inventory.reserve(5)

        assertThatThrownBy { inventory.release(6) }
            .isInstanceOf(IllegalArgumentException::class.java)
            .hasMessageContaining("예약량을 초과 해제 불가")
    }

    @Test
    fun `commit 호출 시 stockQuantity 와 reserved 모두 감소 후 StockCommittedEvent 발행`() {
        val inventory = Inventory.create(productId, 100)
        inventory.reserve(10)
        inventory.clearEvents()

        inventory.commit(10)

        assertThat(inventory.stockQuantity).isEqualTo(90)
        assertThat(inventory.reserved).isEqualTo(0)
        assertThat(inventory.available).isEqualTo(90)
        assertThat(inventory.events).hasSize(1)
        assertThat(inventory.events[0]).isEqualTo(StockCommittedEvent(productId, 10))
    }

    @Test
    fun `commit 수량이 reserved 를 초과하면 IllegalArgumentException`() {
        val inventory = Inventory.create(productId, 100)
        inventory.reserve(5)

        assertThatThrownBy { inventory.commit(6) }
            .isInstanceOf(IllegalArgumentException::class.java)
            .hasMessageContaining("예약량을 초과 확정 불가")
    }

    @Test
    fun `available 은 stockQuantity 마이너스 reserved`() {
        val inventory = Inventory.create(productId, 100)
        inventory.reserve(30)

        assertThat(inventory.available).isEqualTo(inventory.stockQuantity - inventory.reserved)
        assertThat(inventory.available).isEqualTo(70)
    }

    @Test
    fun `clearEvents 호출 후 events 는 비어있다`() {
        val inventory = Inventory.create(productId, 100)
        inventory.reserve(10)
        assertThat(inventory.events).isNotEmpty()

        inventory.clearEvents()

        assertThat(inventory.events).isEmpty()
    }
}
