package com.ecommerce.inventory.domain

import com.ecommerce.order.domain.ProductId

// ─── Domain Events ─────────────────────────────────────────────────────────
sealed interface InventoryEvent
data class StockReservedEvent(val productId: ProductId, val quantity: Int) : InventoryEvent
data class StockReleasedEvent(val productId: ProductId, val quantity: Int) : InventoryEvent
data class StockCommittedEvent(val productId: ProductId, val quantity: Int) : InventoryEvent

// ─── Inventory (Aggregate) ────────────────────────────────────────────────
class Inventory private constructor(
    val productId: ProductId,
    private var _stockQuantity: Int,
    private var _reserved: Int,
) {
    val stockQuantity: Int get() = _stockQuantity
    val reserved: Int get() = _reserved
    val available: Int get() = _stockQuantity - _reserved

    private val _events: MutableList<InventoryEvent> = mutableListOf()
    val events: List<InventoryEvent> get() = _events.toList()
    fun clearEvents() { _events.clear() }

    /** 결제 흐름 시작 시 재고를 hold (실제 차감은 commit 시점). */
    fun reserve(quantity: Int) {
        require(quantity > 0) { "예약 수량은 1 이상이어야 합니다: $quantity" }
        check(available >= quantity) { "가용 재고 부족 (가용=$available, 요청=$quantity)" }
        _reserved += quantity
        _events.add(StockReservedEvent(productId, quantity))
    }

    /** 결제 실패/취소 시 reservation 해제. */
    fun release(quantity: Int) {
        require(quantity > 0) { "해제 수량은 1 이상이어야 합니다: $quantity" }
        require(quantity <= _reserved) { "예약량을 초과 해제 불가 (예약=$_reserved, 요청=$quantity)" }
        _reserved -= quantity
        _events.add(StockReleasedEvent(productId, quantity))
    }

    /** 결제 확정 시 reservation 을 실재고 차감으로 전환. */
    fun commit(quantity: Int) {
        require(quantity > 0) { "확정 수량은 1 이상이어야 합니다: $quantity" }
        require(quantity <= _reserved) { "예약량을 초과 확정 불가 (예약=$_reserved, 요청=$quantity)" }
        _stockQuantity -= quantity
        _reserved -= quantity
        _events.add(StockCommittedEvent(productId, quantity))
    }

    companion object {
        fun create(productId: ProductId, stockQuantity: Int): Inventory {
            require(stockQuantity >= 0) { "초기 재고는 0 이상이어야 합니다: $stockQuantity" }
            return Inventory(productId, stockQuantity, 0)
        }
    }
}
