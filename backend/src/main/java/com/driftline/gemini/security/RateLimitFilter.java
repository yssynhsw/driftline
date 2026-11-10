package com.driftline.gemini.security;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.core.annotation.Order;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import com.driftline.gemini.config.DriftlineProperties;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

@Component
@Order(2)
public class RateLimitFilter extends OncePerRequestFilter {

	private final DriftlineProperties properties;
	private final Map<String, Deque<Long>> buckets = new ConcurrentHashMap<>();

	public RateLimitFilter(DriftlineProperties properties) {
		this.properties = properties;
	}

	@Override
	protected boolean shouldNotFilter(HttpServletRequest request) {
		String path = request.getRequestURI();
		return !path.startsWith("/api/v1/gemini/");
	}

	@Override
	protected void doFilterInternal(
			HttpServletRequest request,
			HttpServletResponse response,
			FilterChain filterChain
	) throws ServletException, IOException {
		int limit = Math.max(1, properties.getSecurity().getRateLimitPerMinute());
		String key = clientKey(request);
		long now = System.currentTimeMillis();
		long windowStart = now - 60_000L;

		Deque<Long> timestamps = buckets.computeIfAbsent(key, ignored -> new ArrayDeque<>());
		synchronized (timestamps) {
			while (!timestamps.isEmpty() && timestamps.peekFirst() < windowStart) {
				timestamps.removeFirst();
			}
			if (timestamps.size() >= limit) {
				response.setStatus(429);
				response.setHeader("Retry-After", "60");
				response.setContentType(MediaType.APPLICATION_JSON_VALUE);
				response.getOutputStream()
						.write("{\"code\":\"rate_limited\",\"message\":\"Too many AI requests. Retry in a minute.\"}"
								.getBytes(StandardCharsets.UTF_8));
				return;
			}
			timestamps.addLast(now);
		}

		filterChain.doFilter(request, response);
	}

	private static String clientKey(HttpServletRequest request) {
		String forwarded = request.getHeader("X-Forwarded-For");
		if (forwarded != null && !forwarded.isBlank()) {
			return forwarded.split(",")[0].trim();
		}
		String token = request.getHeader("X-Driftline-Token");
		if (token != null && !token.isBlank()) {
			return "token:" + Integer.toHexString(token.hashCode());
		}
		return request.getRemoteAddr();
	}
}
