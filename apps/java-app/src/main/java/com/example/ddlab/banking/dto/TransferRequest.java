package com.example.ddlab.banking.dto;

import java.math.BigDecimal;

public record TransferRequest(
        String toAccountNumber,
        String beneficiaryKanji,
        String beneficiaryHiragana,
        BigDecimal amount) {
}
