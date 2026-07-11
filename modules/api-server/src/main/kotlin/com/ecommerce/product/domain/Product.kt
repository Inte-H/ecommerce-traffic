package com.ecommerce.product.domain

import com.ecommerce.sharedkernel.domain.Money

// ─── Value Objects ──────────────────────────────────────────────────────────
// value class: 카테고리 ID 타입 안전성 보장
@JvmInline value class ProductId(val value: Long)
@JvmInline value class CategoryId(val value: Long)

// ─── Product (data class — 읽기 중심, 불변) ────────────────────────────────
data class Product(
    val id: ProductId,
    val name: String,
    val price: Money,
    val discountedPrice: Money?,    // null = 할인 없음 (null-safety 학습 포인트)
    val categoryId: CategoryId,
    val description: String?,        // 선택적 — null 가능
) {
    init {
        require(name.isNotBlank()) { "상품명은 비어있을 수 없습니다" }
        require(name.length <= 200) { "상품명은 200자 이하여야 합니다: ${name.length}" }
        // null-safety idiom: ?.let { ... } — discountedPrice 가 null 이면 검증 스킵
        discountedPrice?.let {
            require(it.amount < price.amount) {
                "할인가는 정가보다 낮아야 합니다 (정가=$price, 할인가=$it)"
            }
        }
    }

    /** 실제 적용 가격 — 할인 있으면 할인가, 없으면 정가. null-safety의 elvis(?:) 활용. */
    val effectivePrice: Money get() = discountedPrice ?: price

    /** 할인율(%). 할인 없으면 0. */
    val discountPercent: Int
        get() = discountedPrice?.let {
            ((price.amount - it.amount) * 100 / price.amount).toInt()
        } ?: 0
}
