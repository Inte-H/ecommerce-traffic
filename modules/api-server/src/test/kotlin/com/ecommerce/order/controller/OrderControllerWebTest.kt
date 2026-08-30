package com.ecommerce.order.controller

import com.ecommerce.order.application.InsufficientStockException
import com.ecommerce.order.application.PlaceOrderCommand
import com.ecommerce.order.application.PlaceOrderResult
import com.ecommerce.order.application.PlaceOrderService
import com.ecommerce.order.domain.CustomerId
import com.ecommerce.order.domain.OrderId
import com.ecommerce.product.domain.ProductId
import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.mockito.BDDMockito.given
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest
import org.springframework.http.MediaType
import org.springframework.test.context.bean.override.mockito.MockitoBean
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status

@WebMvcTest(OrderController::class)
class OrderControllerWebTest {

    @Autowired
    private lateinit var mockMvc: MockMvc

    private val objectMapper: ObjectMapper = jacksonObjectMapper()

    @MockitoBean
    private lateinit var placeOrderService: PlaceOrderService

    // ─── 테스트용 헬퍼 ──────────────────────────────────────────────────────────

    private fun requestJson(
        customerId: Long = 1L,
        productId: Long = 2L,
        quantity: Int = 3,
        addressId: Long = 4L,
    ): String {
        return objectMapper.writeValueAsString(
            PlaceOrderRequest(
                customerId = customerId,
                productId = productId,
                quantity = quantity,
                addressId = addressId,
            )
        )
    }

    private fun sampleCommand(
        customerId: Long = 1L,
        productId: Long = 2L,
        quantity: Int = 3,
        addressId: Long = 4L,
    ) = PlaceOrderCommand(
        customerId = CustomerId(customerId),
        productId = ProductId(productId),
        quantity = quantity,
        addressId = addressId,
    )

    // ─── 정상 흐름 ──────────────────────────────────────────────────────────────

    @Test
    fun `유효한 요청이면 201과 orderId 를 반환한다`() {
        given(placeOrderService.place(sampleCommand())).willReturn(PlaceOrderResult(OrderId(99L)))

        mockMvc.perform(
            post("/api/orders/place")
                .contentType(MediaType.APPLICATION_JSON)
                .content(requestJson())
        )
            .andExpect(status().isCreated)
            .andExpect(jsonPath("$.orderId").value(99))
    }

    // ─── 요청 검증 ─────────────────────────────────────────────────────────────

    @Test
    fun `quantity 가 0 이면 400을 반환한다`() {
        mockMvc.perform(
            post("/api/orders/place")
                .contentType(MediaType.APPLICATION_JSON)
                .content(requestJson(quantity = 0))
        )
            .andExpect(status().isBadRequest)
    }

    @Test
    fun `customerId 가 음수이면 400을 반환한다`() {
        mockMvc.perform(
            post("/api/orders/place")
                .contentType(MediaType.APPLICATION_JSON)
                .content(requestJson(customerId = -1L))
        )
            .andExpect(status().isBadRequest)
    }

    @Test
    fun `요청 본문이 깨진 JSON 이면 400과 메시지를 반환한다`() {
        val result = mockMvc.perform(
            post("/api/orders/place")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{ this is not valid json")
        )
            .andExpect(status().isBadRequest)
            .andReturn()

        assertThat(result.response.contentAsString).contains("message")
    }

    // ─── 예외 전파 ─────────────────────────────────────────────────────────────

    @Test
    fun `서비스가 IllegalStateException 을 던지면 500과 원인 메시지를 반환한다`() {
        val message = "Product stock was not updated: productId=1"
        given(placeOrderService.place(sampleCommand())).willThrow(IllegalStateException(message))

        mockMvc.perform(
            post("/api/orders/place")
                .contentType(MediaType.APPLICATION_JSON)
                .content(requestJson())
        )
            .andExpect(status().isInternalServerError)
            .andExpect(jsonPath("$.message").value(message))
    }

    @Test
    fun `서비스가 InsufficientStockException 을 던지면 409를 반환한다`() {
        given(placeOrderService.place(sampleCommand()))
            .willThrow(InsufficientStockException(ProductId(2L), 3))

        mockMvc.perform(
            post("/api/orders/place")
                .contentType(MediaType.APPLICATION_JSON)
                .content(requestJson())
        )
            .andExpect(status().isConflict)
    }
}
