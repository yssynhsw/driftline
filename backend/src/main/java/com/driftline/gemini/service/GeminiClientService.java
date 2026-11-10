package com.driftline.gemini.service;

import java.net.URI;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;

import com.driftline.gemini.config.DriftlineProperties;
import com.driftline.gemini.web.dto.GeminiProxyRequest;

@Service
public class GeminiClientService {

	private static final Logger log = LoggerFactory.getLogger(GeminiClientService.class);

	private static final List<String> FALLBACK_MODELS = List.of(
			"gemini-3-flash-preview",
			"gemini-3.1-flash-lite",
			"gemini-flash-lite-latest",
			"gemini-flash-latest",
			"gemini-2.5-flash",
			"gemini-2.5-flash-lite",
			"gemini-3.5-flash"
	);

	private final DriftlineProperties properties;
	private final RestClient.Builder restClientBuilder;

	public GeminiClientService(DriftlineProperties properties, RestClient.Builder restClientBuilder) {
		this.properties = properties;
		this.restClientBuilder = restClientBuilder;
	}

	public Map<String, Object> generate(GeminiProxyRequest proxyRequest) {
		DriftlineProperties.Gemini gemini = properties.getGemini();
		if (!gemini.isConfigured()) {
			throw new GeminiUpstreamException(503, "Gemini is not configured on the server.");
		}

		Map<String, Object> body = resolveBody(proxyRequest);
		GeminiUpstreamException lastError = null;
		for (String model : candidateModels(proxyRequest.getModel(), gemini.getModel())) {
			URI uri = URI.create(trimTrailingSlash(gemini.getBaseUrl())
					+ "/models/"
					+ model
					+ ":generateContent?key="
					+ gemini.getApiKey().trim());
			try {
				@SuppressWarnings("unchecked")
				Map<String, Object> response = restClientBuilder.build()
						.post()
						.uri(uri)
						.contentType(MediaType.APPLICATION_JSON)
						.body(body)
						.retrieve()
						.body(Map.class);
				if (response == null || response.isEmpty()) {
					lastError = new GeminiUpstreamException(502, "Empty response from Gemini.");
					continue;
				}
				log.info("Gemini upstream OK with model {}", model);
				return response;
			}
			catch (RestClientResponseException ex) {
				int status = ex.getStatusCode().value();
				log.warn("Gemini upstream HTTP {} for model {}", status, model);
				if (status == 401 || status == 403) {
					throw new GeminiUpstreamException(502, "Gemini authentication failed on the server.");
				}
				if (status == 429) {
					lastError = new GeminiUpstreamException(429, "Gemini quota exceeded. Retry later.");
					continue;
				}
				if (status == 404 || status == 503 || status == 500) {
					lastError = new GeminiUpstreamException(
							status == 404 ? 502 : 503,
							status == 404
									? "Configured Gemini model is unavailable."
									: "Gemini is temporarily unavailable. Retry later."
					);
					continue;
				}
				throw new GeminiUpstreamException(502, "Gemini upstream error (" + status + ").");
			}
			catch (GeminiUpstreamException ex) {
				throw ex;
			}
			catch (Exception ex) {
				log.warn("Gemini upstream call failed on {}: {}", model, ex.getClass().getSimpleName());
				lastError = new GeminiUpstreamException(504, "Gemini request timed out or could not be reached.");
			}
		}
		throw lastError != null
				? lastError
				: new GeminiUpstreamException(503, "Gemini is temporarily unavailable. Retry later.");
	}

	private static List<String> candidateModels(String requested, String configured) {
		Set<String> ordered = new LinkedHashSet<>();
		String primary = resolveModel(requested, configured);
		if (primary != null && !primary.isBlank()) {
			ordered.add(primary);
		}
		ordered.addAll(FALLBACK_MODELS);
		return new ArrayList<>(ordered);
	}

	private static String resolveModel(String requested, String fallback) {
		if (requested == null || requested.isBlank()) {
			return fallback;
		}
		String cleaned = requested.trim();
		if (!cleaned.matches("[A-Za-z0-9._-]{3,80}")) {
			return fallback;
		}
		return cleaned;
	}

	private static Map<String, Object> resolveBody(GeminiProxyRequest proxyRequest) {
		if (proxyRequest.getRequest() != null && !proxyRequest.getRequest().isEmpty()) {
			return proxyRequest.getRequest();
		}

		Map<String, Object> part = new HashMap<>();
		part.put("text", proxyRequest.getPrompt());

		Map<String, Object> content = new HashMap<>();
		content.put("role", "user");
		content.put("parts", List.of(part));

		Map<String, Object> generationConfig = new HashMap<>();
		generationConfig.put("temperature", 0.7);
		generationConfig.put("responseMimeType", "application/json");

		Map<String, Object> body = new HashMap<>();
		body.put("contents", List.of(content));
		body.put("generationConfig", generationConfig);
		return body;
	}

	private static String trimTrailingSlash(String value) {
		if (value.endsWith("/")) {
			return value.substring(0, value.length() - 1);
		}
		return value;
	}
}
