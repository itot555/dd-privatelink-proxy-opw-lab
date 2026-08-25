package com.example.ddlab.banking.dto;

public record ProfileRequest(
        String holderNameKanji,
        String holderNameHiragana,
        String addressKanji,
        String addressHiragana,
        String postalCode) {}
