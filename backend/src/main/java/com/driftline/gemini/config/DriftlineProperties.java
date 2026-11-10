package com.driftline.gemini.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "driftline")
public class DriftlineProperties {

	private final Gemini gemini = new Gemini();
	private final Security security = new Security();

	public Gemini getGemini() {
		return gemini;
	}

	public Security getSecurity() {
		return security;
	}

	public static class Gemini {
		private String apiKey = "";
		private String model = "gemini-3-flash-preview";
		private String baseUrl = "https://generativelanguage.googleapis.com/v1beta";
		private int timeoutMs = 55_000;

		public String getApiKey() {
			return apiKey;
		}

		public void setApiKey(String apiKey) {
			this.apiKey = apiKey;
		}

		public String getModel() {
			return model;
		}

		public void setModel(String model) {
			this.model = model;
		}

		public String getBaseUrl() {
			return baseUrl;
		}

		public void setBaseUrl(String baseUrl) {
			this.baseUrl = baseUrl;
		}

		public int getTimeoutMs() {
			return timeoutMs;
		}

		public void setTimeoutMs(int timeoutMs) {
			this.timeoutMs = timeoutMs;
		}

		public boolean isConfigured() {
			return apiKey != null && apiKey.trim().length() >= 20;
		}
	}

	public static class Security {
		private String appToken = "";
		private int rateLimitPerMinute = 12;

		public String getAppToken() {
			return appToken;
		}

		public void setAppToken(String appToken) {
			this.appToken = appToken;
		}

		public int getRateLimitPerMinute() {
			return rateLimitPerMinute;
		}

		public void setRateLimitPerMinute(int rateLimitPerMinute) {
			this.rateLimitPerMinute = rateLimitPerMinute;
		}

		public boolean isTokenRequired() {
			return appToken != null && !appToken.isBlank();
		}
	}
}
