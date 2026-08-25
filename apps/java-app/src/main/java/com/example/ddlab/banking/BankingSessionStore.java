package com.example.ddlab.banking;

import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.stereotype.Component;

@Component
public class BankingSessionStore {

    private final Map<String, String> sessions = new ConcurrentHashMap<>();

    String createSession(String loginId) {
        String token = UUID.randomUUID().toString();
        sessions.put(token, loginId);
        return token;
    }

    Optional<String> resolveLoginId(String token) {
        if (token == null || token.isBlank()) {
            return Optional.empty();
        }
        return Optional.ofNullable(sessions.get(token));
    }
}
