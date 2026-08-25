package com.example.ddlab.banking;

import java.net.URI;
import java.util.List;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.HttpStatusCodeException;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriComponentsBuilder;

import com.example.ddlab.banking.dto.LoginResponse;
import com.example.ddlab.banking.dto.TransferRequest;

@Service
@ConditionalOnProperty(name = "banking.demo.enabled", havingValue = "true")
public class BankingService {

    private static final Logger LOGGER = LoggerFactory.getLogger(BankingService.class);

    private final RestTemplate restTemplate;
    private final BankingDemoProperties properties;
    private final BankingSessionStore sessionStore;
    private final String pythonApiUrl;

    BankingService(
            RestTemplate restTemplate,
            BankingDemoProperties properties,
            BankingSessionStore sessionStore,
            @Value("${python.api.url}") String pythonApiUrl) {
        this.restTemplate = restTemplate;
        this.properties = properties;
        this.sessionStore = sessionStore;
        this.pythonApiUrl = pythonApiUrl;
    }

    LoginResponse login(String loginId, String password) {
        LOGGER.info(
                "Banking login attempt login_id={} password={}",
                loginId,
                password);

        if (loginId == null
                || loginId.isBlank()
                || password == null
                || password.isBlank()
                || !password.equals(properties.getPassword())) {
            throw new BankingException("invalid credentials");
        }

        Map<String, Object> user = fetchUser(loginId);
        String displayName = String.valueOf(user.get("displayName"));
        String token = sessionStore.createSession(loginId);
        return new LoginResponse(token, loginId, displayName);
    }

    Map<String, Object> getBalance(String token) {
        String loginId = requireLoginId(token);
        URI uri = UriComponentsBuilder
                .fromUriString(pythonApiUrl + "/api/banking/balance")
                .queryParam("login_id", loginId)
                .build()
                .toUri();

        LOGGER.info("Fetching balance for login_id={}", loginId);
        ResponseEntity<Map<String, Object>> response = restTemplate.exchange(
                uri,
                HttpMethod.GET,
                null,
                new ParameterizedTypeReference<>() {});

        return response.getBody();
    }

    Map<String, Object> createTransfer(String token, TransferRequest request) {
        String loginId = requireLoginId(token);

        LOGGER.info(
                "Transfer request login_id={} to={} beneficiary_kanji={} beneficiary_hiragana={} amount={}",
                loginId,
                request.toAccountNumber(),
                request.beneficiaryKanji(),
                request.beneficiaryHiragana(),
                request.amount());

        Map<String, Object> payload = Map.of(
                "loginId", loginId,
                "toAccountNumber", request.toAccountNumber(),
                "beneficiaryKanji", request.beneficiaryKanji(),
                "beneficiaryHiragana", request.beneficiaryHiragana(),
                "amount", request.amount());

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        HttpEntity<Map<String, Object>> entity = new HttpEntity<>(payload, headers);

        ResponseEntity<Map<String, Object>> response = restTemplate.exchange(
                pythonApiUrl + "/api/banking/transfers",
                HttpMethod.POST,
                entity,
                new ParameterizedTypeReference<>() {});

        return response.getBody();
    }

    List<Map<String, Object>> listTransactions(String token) {
        String loginId = requireLoginId(token);
        URI uri = UriComponentsBuilder
                .fromUriString(pythonApiUrl + "/api/banking/transactions")
                .queryParam("login_id", loginId)
                .build()
                .toUri();

        LOGGER.info("Listing transactions for login_id={}", loginId);
        ResponseEntity<Map<String, Object>> response = restTemplate.exchange(
                uri,
                HttpMethod.GET,
                null,
                new ParameterizedTypeReference<>() {});

        Map<String, Object> body = response.getBody();
        if (body == null || body.get("transactions") == null) {
            return List.of();
        }

        @SuppressWarnings("unchecked")
        List<Map<String, Object>> transactions = (List<Map<String, Object>>) body.get("transactions");
        return transactions;
    }

    Map<String, Object> getProfile(String token) {
        String loginId = requireLoginId(token);
        URI uri = UriComponentsBuilder
                .fromUriString(pythonApiUrl + "/api/banking/profile")
                .queryParam("login_id", loginId)
                .build()
                .toUri();

        LOGGER.info("Fetching profile for login_id={}", loginId);
        ResponseEntity<Map<String, Object>> response = restTemplate.exchange(
                uri, HttpMethod.GET, null, new ParameterizedTypeReference<>() {});

        return response.getBody();
    }

    Map<String, Object> updateProfile(String token, com.example.ddlab.banking.dto.ProfileRequest request) {
        String loginId = requireLoginId(token);

        LOGGER.info(
                "Profile update login_id={} holder_kanji={} holder_hiragana={} "
                        + "address_kanji={} address_hiragana={} postal_code={}",
                loginId,
                request.holderNameKanji(),
                request.holderNameHiragana(),
                request.addressKanji(),
                request.addressHiragana(),
                request.postalCode());

        Map<String, Object> payload = Map.of(
                "loginId", loginId,
                "holderNameKanji", request.holderNameKanji(),
                "holderNameHiragana", request.holderNameHiragana(),
                "addressKanji", request.addressKanji(),
                "addressHiragana", request.addressHiragana(),
                "postalCode", request.postalCode() == null ? "" : request.postalCode());

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        HttpEntity<Map<String, Object>> entity = new HttpEntity<>(payload, headers);

        ResponseEntity<Map<String, Object>> response = restTemplate.exchange(
                pythonApiUrl + "/api/banking/profile",
                HttpMethod.PUT,
                entity,
                new ParameterizedTypeReference<>() {});

        return response.getBody();
    }

    List<Map<String, Object>> searchAccounts(String token, String query) {
        requireLoginId(token);

        LOGGER.info("Account search q={}", query);

        URI uri = UriComponentsBuilder
                .fromUriString(pythonApiUrl + "/api/banking/accounts/search")
                .queryParam("q", query)
                .build()
                .toUri();

        ResponseEntity<Map<String, Object>> response = restTemplate.exchange(
                uri, HttpMethod.GET, null, new ParameterizedTypeReference<>() {});

        Map<String, Object> body = response.getBody();
        if (body == null || body.get("results") == null) {
            return List.of();
        }

        @SuppressWarnings("unchecked")
        List<Map<String, Object>> results = (List<Map<String, Object>>) body.get("results");
        return results;
    }

    private String requireLoginId(String token) {
        return sessionStore
                .resolveLoginId(extractBearerToken(token))
                .orElseThrow(() -> new BankingException("unauthorized"));
    }

    private Map<String, Object> fetchUser(String loginId) {
        try {
            ResponseEntity<Map<String, Object>> response = restTemplate.exchange(
                    pythonApiUrl + "/api/banking/users/by-login/" + loginId,
                    HttpMethod.GET,
                    null,
                    new ParameterizedTypeReference<>() {});

            Map<String, Object> body = response.getBody();
            if (body == null || body.get("displayName") == null) {
                throw new BankingException("invalid credentials");
            }
            return body;
        } catch (HttpStatusCodeException exception) {
            throw new BankingException("invalid credentials");
        }
    }

    static String extractBearerToken(String authorizationHeader) {
        if (authorizationHeader == null || !authorizationHeader.startsWith("Bearer ")) {
            return "";
        }
        return authorizationHeader.substring("Bearer ".length()).trim();
    }

    static class BankingException extends RuntimeException {
        BankingException(String message) {
            super(message);
        }
    }
}
