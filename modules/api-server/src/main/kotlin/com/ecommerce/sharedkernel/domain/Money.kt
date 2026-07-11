package com.ecommerce.sharedkernel.domain

@JvmInline
value class Money(val amount: Long) {
    init {
        require(amount >= 0) { "금액은 0 이상이어야 합니다: $amount" }
    }

    operator fun plus(other: Money): Money = Money(amount + other.amount)
}
