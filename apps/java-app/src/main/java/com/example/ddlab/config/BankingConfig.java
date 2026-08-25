package com.example.ddlab.config;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;

import com.example.ddlab.banking.BankingDemoProperties;

@Configuration
@EnableConfigurationProperties(BankingDemoProperties.class)
public class BankingConfig {
}
