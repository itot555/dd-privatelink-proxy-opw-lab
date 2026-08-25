package com.example.ddlab.banking;

import java.util.List;
import java.util.Map;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.example.ddlab.banking.BankingService.BankingException;
import com.example.ddlab.banking.dto.LoginRequest;
import com.example.ddlab.banking.dto.LoginResponse;
import com.example.ddlab.banking.dto.ProfileRequest;
import com.example.ddlab.banking.dto.TransferRequest;

@RestController
@ConditionalOnProperty(name = "banking.demo.enabled", havingValue = "true")
public class BankingController {

    private final BankingService bankingService;

    BankingController(BankingService bankingService) {
        this.bankingService = bankingService;
    }

    @PostMapping("/api/auth/login")
    ResponseEntity<LoginResponse> login(@RequestBody LoginRequest request) {
        LoginResponse response = bankingService.login(request.loginId(), request.password());
        return ResponseEntity.ok(response);
    }

    @GetMapping("/api/accounts/balance")
    ResponseEntity<Map<String, Object>> balance(
            @RequestHeader(value = "Authorization", required = false) String authorization) {
        return ResponseEntity.ok(bankingService.getBalance(authorization));
    }

    @PostMapping("/api/transfers")
    ResponseEntity<Map<String, Object>> transfer(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @RequestBody TransferRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(bankingService.createTransfer(authorization, request));
    }

    @GetMapping("/api/transactions")
    ResponseEntity<List<Map<String, Object>>> transactions(
            @RequestHeader(value = "Authorization", required = false) String authorization) {
        return ResponseEntity.ok(bankingService.listTransactions(authorization));
    }

    @GetMapping("/api/profile")
    ResponseEntity<Map<String, Object>> profile(
            @RequestHeader(value = "Authorization", required = false) String authorization) {
        return ResponseEntity.ok(bankingService.getProfile(authorization));
    }

    @PutMapping("/api/profile")
    ResponseEntity<Map<String, Object>> updateProfile(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @RequestBody ProfileRequest request) {
        return ResponseEntity.ok(bankingService.updateProfile(authorization, request));
    }

    @GetMapping("/api/accounts/search")
    ResponseEntity<List<Map<String, Object>>> searchAccounts(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @RequestParam("q") String query) {
        return ResponseEntity.ok(bankingService.searchAccounts(authorization, query));
    }

    @ExceptionHandler(BankingException.class)
    ResponseEntity<Map<String, String>> handleBankingException(BankingException exception) {
        HttpStatus status = "unauthorized".equals(exception.getMessage())
                ? HttpStatus.UNAUTHORIZED
                : HttpStatus.BAD_REQUEST;
        return ResponseEntity.status(status).body(Map.of("error", exception.getMessage()));
    }
}
