package com.ecommerce.sharedkernel.controller

import com.ecommerce.order.application.InsufficientStockException
import com.ecommerce.order.application.ProductNotFoundException
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.ExceptionHandler
import org.springframework.web.bind.annotation.RestControllerAdvice

@RestControllerAdvice
class ApiExceptionHandler {
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
}

data class ApiErrorResponse(
    val message: String,
)
