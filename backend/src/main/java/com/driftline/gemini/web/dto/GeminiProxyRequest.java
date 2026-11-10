package com.driftline.gemini.web.dto;

import java.util.Map;

import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.Size;

public class GeminiProxyRequest {

	@Size(max = 40_000)
	private String prompt;

	@Size(max = 80)
	private String model;

	private Map<String, Object> request;

	public String getPrompt() {
		return prompt;
	}

	public void setPrompt(String prompt) {
		this.prompt = prompt;
	}

	public String getModel() {
		return model;
	}

	public void setModel(String model) {
		this.model = model;
	}

	public Map<String, Object> getRequest() {
		return request;
	}

	public void setRequest(Map<String, Object> request) {
		this.request = request;
	}

	@AssertTrue(message = "prompt or request is required")
	public boolean hasPayload() {
		boolean hasPrompt = prompt != null && !prompt.isBlank();
		boolean hasRequest = request != null && !request.isEmpty();
		return hasPrompt || hasRequest;
	}
}
