package com.driftline.gemini.config;

import java.time.Duration;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.web.client.RestClient;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
@EnableConfigurationProperties(DriftlineProperties.class)
public class AppConfig {

	@Bean
	RestClient.Builder restClientBuilder(DriftlineProperties properties) {
		JdkClientHttpRequestFactory factory = new JdkClientHttpRequestFactory();
		factory.setReadTimeout(Duration.ofMillis(Math.max(5_000, properties.getGemini().getTimeoutMs())));
		return RestClient.builder().requestFactory(factory);
	}

	@Bean
	WebMvcConfigurer corsConfigurer() {
		return new WebMvcConfigurer() {
			@Override
			public void addCorsMappings(CorsRegistry registry) {
				registry.addMapping("/api/**")
						.allowedOriginPatterns("*")
						.allowedMethods("GET", "POST", "OPTIONS")
						.allowedHeaders("*")
						.maxAge(3600);
			}
		};
	}
}
