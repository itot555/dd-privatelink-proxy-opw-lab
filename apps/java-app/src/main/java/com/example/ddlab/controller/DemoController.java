package com.example.ddlab.controller;

import java.net.URI;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriComponentsBuilder;

@RestController
public class DemoController {

    private static final Logger LOGGER = LoggerFactory.getLogger(DemoController.class);

    private final RestTemplate restTemplate;
    private final String pythonApiUrl;

    DemoController(
            RestTemplate restTemplate,
            @Value("${python.api.url}") String pythonApiUrl) {
        this.restTemplate = restTemplate;
        this.pythonApiUrl = pythonApiUrl;
    }

    @GetMapping("/hello")
    ResponseEntity<String> hello() {
        LOGGER.info("Calling Python API and PostgreSQL");
        return restTemplate.getForEntity(pythonApiUrl + "/api/items", String.class);
    }

    @PostMapping("/items")
    ResponseEntity<String> createItem(@RequestParam(defaultValue = "sample-item") String name) {
        URI uri = UriComponentsBuilder
                .fromUriString(pythonApiUrl + "/api/items")
                .queryParam("name", name)
                .build()
                .toUri();
        LOGGER.info("Creating item through Python API: {}", name);
        return restTemplate.postForEntity(uri, null, String.class);
    }

    @GetMapping("/timeout")
    ResponseEntity<String> timeout() {
        LOGGER.info("Calling delayed PostgreSQL query through Python API");
        return restTemplate.getForEntity(pythonApiUrl + "/api/timeout", String.class);
    }

    @GetMapping("/error")
    ResponseEntity<String> error() {
        LOGGER.info("Calling failing PostgreSQL query through Python API");
        return restTemplate.getForEntity(pythonApiUrl + "/api/error", String.class);
    }

    @GetMapping("/health")
    Map<String, String> health() {
        return Map.of("status", "ok", "service", "dd-lab-java");
    }
}
