package com.driftline.gemini.service;

public class GeminiUpstreamException extends RuntimeException {

	private final int status;

	public GeminiUpstreamException(int status, String message) {
		super(message);
		this.status = status;
	}

	public int getStatus() {
		return status;
	}
}
