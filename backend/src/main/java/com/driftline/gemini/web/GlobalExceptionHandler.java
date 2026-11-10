package com.driftline.gemini.web;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import com.driftline.gemini.service.GeminiUpstreamException;
import com.driftline.gemini.web.dto.ApiError;

@RestControllerAdvice
public class GlobalExceptionHandler {

	@ExceptionHandler(GeminiUpstreamException.class)
	public ResponseEntity<ApiError> handleUpstream(GeminiUpstreamException ex) {
		HttpStatus status = HttpStatus.resolve(ex.getStatus());
		if (status == null) {
			status = HttpStatus.BAD_GATEWAY;
		}
		return ResponseEntity.status(status)
				.body(new ApiError("gemini_upstream", ex.getMessage()));
	}

	@ExceptionHandler(MethodArgumentNotValidException.class)
	public ResponseEntity<ApiError> handleValidation(MethodArgumentNotValidException ex) {
		return ResponseEntity.badRequest()
				.body(new ApiError("invalid_request", "Invalid Gemini proxy payload."));
	}

	@ExceptionHandler(Exception.class)
	public ResponseEntity<ApiError> handleGeneric(Exception ex) {
		return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
				.body(new ApiError("server_error", "Unexpected server error."));
	}
}
