package com.driftline.gemini.web;

import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.driftline.gemini.config.DriftlineProperties;
import com.driftline.gemini.service.GeminiClientService;
import com.driftline.gemini.web.dto.GeminiProxyRequest;

import jakarta.validation.Valid;

@RestController
@Validated
@RequestMapping("/api/v1/gemini")
public class GeminiController {

	private final GeminiClientService geminiClientService;
	private final DriftlineProperties properties;

	public GeminiController(GeminiClientService geminiClientService, DriftlineProperties properties) {
		this.geminiClientService = geminiClientService;
		this.properties = properties;
	}

	@GetMapping("/health")
	public Map<String, Object> health() {
		return Map.of(
				"status", "ok",
				"geminiConfigured", properties.getGemini().isConfigured(),
				"tokenRequired", properties.getSecurity().isTokenRequired(),
				"model", properties.getGemini().getModel()
		);
	}

	@PostMapping("/generate")
	public ResponseEntity<Map<String, Object>> generate(@Valid @RequestBody GeminiProxyRequest request) {
		Map<String, Object> upstream = geminiClientService.generate(request);
		return ResponseEntity.ok(upstream);
	}
}
