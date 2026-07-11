package com.ecommerce.sharedkernel.controller

import com.ecommerce.order.application.InsufficientStockException
import com.ecommerce.order.application.ProductNotFoundException
import org.slf4j.LoggerFactory
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.ExceptionHandler
import org.springframework.web.bind.annotation.RestControllerAdvice

@RestControllerAdvice
class ApiExceptionHandler {

    private val log = LoggerFactory.getLogger(ApiExceptionHandler::class.java)

    @ExceptionHandler(ProductNotFoundException::class)
    fun handleProductNotFound(exception: ProductNotFoundException): ResponseEntity<ApiErrorResponse> {
        return ResponseEntity
            .status(HttpStatus.NOT_FOUND)
            .body(ApiErrorResponse(message = exception.message ?: "Product not found"))
    }

    @ExceptionHandler(InsufficientStockException::class)
    fun handleInsufficientStock(exception: InsufficientStockException): ResponseEntity<ApiErrorResponse> {
        return ResponseEntity
            .status(HttpStatus.CONFLICT)
            .body(ApiErrorResponse(message = exception.message ?: "Insufficient stock"))
    }

    @ExceptionHandler(IllegalArgumentException::class)
    fun handleIllegalArgument(exception: IllegalArgumentException): ResponseEntity<ApiErrorResponse> {
        return ResponseEntity
            .status(HttpStatus.BAD_REQUEST)
            .body(ApiErrorResponse(message = exception.message ?: "Invalid request"))
    }

    // 리포지토리 계층의 불변식 위반(check/error)이 body 없는 불투명한 500으로 새어나가면
    // 부하 테스트에서 5xx 원인 해석이 막힌다. 원인을 응답 본문에 노출해 관측 가능하게 만든다.
    @ExceptionHandler(IllegalStateException::class)
    fun handleIllegalState(exception: IllegalStateException): ResponseEntity<ApiErrorResponse> {
        log.error("서버 불변식 위반", exception)
        return ResponseEntity
            .status(HttpStatus.INTERNAL_SERVER_ERROR)
            .body(ApiErrorResponse(message = exception.message ?: "Internal server error"))
    }

    @ExceptionHandler(Exception::class)
    fun handleUnexpected(exception: Exception): ResponseEntity<ApiErrorResponse> {
        log.error("처리되지 않은 예외", exception)
        return ResponseEntity
            .status(HttpStatus.INTERNAL_SERVER_ERROR)
            .body(ApiErrorResponse(message = exception.message ?: "Internal server error"))
    }
}

data class ApiErrorResponse(
    val message: String,
)
