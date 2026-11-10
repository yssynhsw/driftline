package com.driftline.gemini.security;

import java.io.IOException;
import java.nio.charset.StandardCharsets;

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
@Order(1)
public class AppTokenFilter extends OncePerRequestFilter {

	private final DriftlineProperties properties;

	public AppTokenFilter(DriftlineProperties properties) {
		this.properties = properties;
	}

	@Override
	protected boolean shouldNotFilter(HttpServletRequest request) {
		String path = request.getRequestURI();
		if (!path.startsWith("/api/")) {
			return true;
		}
		// Public readiness probe — no secrets exposed.
		return "GET".equalsIgnoreCase(request.getMethod())
				&& path.equals("/api/v1/gemini/health");
	}

	@Override
	protected void doFilterInternal(
			HttpServletRequest request,
			HttpServletResponse response,
			FilterChain filterChain
	) throws ServletException, IOException {
		if (!properties.getSecurity().isTokenRequired()) {
			filterChain.doFilter(request, response);
			return;
		}

		String expected = properties.getSecurity().getAppToken().trim();
		String provided = extractToken(request);
		if (provided == null || !constantTimeEquals(expected, provided)) {
			response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
			response.setContentType(MediaType.APPLICATION_JSON_VALUE);
			response.getOutputStream()
					.write("{\"code\":\"unauthorized\",\"message\":\"Invalid or missing app token.\"}"
							.getBytes(StandardCharsets.UTF_8));
			return;
		}

		filterChain.doFilter(request, response);
	}

	private static String extractToken(HttpServletRequest request) {
		String header = request.getHeader("X-Driftline-Token");
		if (header != null && !header.isBlank()) {
			return header.trim();
		}
		String auth = request.getHeader("Authorization");
		if (auth != null && auth.regionMatches(true, 0, "Bearer ", 0, 7)) {
			return auth.substring(7).trim();
		}
		return null;
	}

	private static boolean constantTimeEquals(String left, String right) {
		byte[] a = left.getBytes(StandardCharsets.UTF_8);
		byte[] b = right.getBytes(StandardCharsets.UTF_8);
		if (a.length != b.length) {
			return false;
		}
		int result = 0;
		for (int i = 0; i < a.length; i++) {
			result |= a[i] ^ b[i];
		}
		return result == 0;
	}
}
