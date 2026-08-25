package com.example.ddlab.banking;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import com.example.ddlab.banking.dto.LoginResponse;
import com.example.ddlab.banking.dto.TransferRequest;

@WebMvcTest(BankingController.class)
@TestPropertySource(properties = "banking.demo.enabled=true")
class BankingControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private BankingService bankingService;

    @Test
    void loginReturnsToken() throws Exception {
        when(bankingService.login(eq("demo_user"), eq("secret")))
                .thenReturn(new LoginResponse("token-1", "demo_user", "デモ太郎"));

        mockMvc.perform(
                        post("/api/auth/login")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("""
                                        {"loginId":"demo_user","password":"secret"}
                                        """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.token").value("token-1"))
                .andExpect(jsonPath("$.displayName").value("デモ太郎"));
    }

    @Test
    void balanceRequiresAuthorization() throws Exception {
        when(bankingService.getBalance("Bearer token-1"))
                .thenReturn(Map.of("balance", 1234567.0, "holderNameKanji", "デモ太郎"));

        mockMvc.perform(get("/api/accounts/balance").header("Authorization", "Bearer token-1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.holderNameKanji").value("デモ太郎"));
    }

    @Test
    void transferCreatesRecord() throws Exception {
        when(bankingService.createTransfer(eq("Bearer token-1"), any(TransferRequest.class)))
                .thenReturn(Map.of("transferId", 1, "balance", 1224567.0));

        mockMvc.perform(
                        post("/api/transfers")
                                .header("Authorization", "Bearer token-1")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("""
                                        {
                                          "toAccountNumber":"9876543",
                                          "beneficiaryKanji":"デモ花子",
                                          "beneficiaryHiragana":"でもはなこ",
                                          "amount":10000
                                        }
                                        """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.transferId").value(1));
    }

    @Test
    void transactionsReturnsList() throws Exception {
        when(bankingService.listTransactions("Bearer token-1"))
                .thenReturn(List.of(Map.of("beneficiaryKanji", "デモ花子", "amount", 10000)));

        mockMvc.perform(get("/api/transactions").header("Authorization", "Bearer token-1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].beneficiaryKanji").value("デモ花子"));
    }

    @Test
    void profileUpdateReturnsProfile() throws Exception {
        when(bankingService.updateProfile(eq("Bearer token-1"), any()))
                .thenReturn(Map.of("holderNameKanji", "デモ太郎", "addressKanji", "東京都千代田区"));

        mockMvc.perform(
                        put("/api/profile")
                                .header("Authorization", "Bearer token-1")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("""
                                        {
                                          "holderNameKanji":"デモ太郎",
                                          "holderNameHiragana":"でもたろう",
                                          "addressKanji":"東京都千代田区",
                                          "addressHiragana":"とうきょうと",
                                          "postalCode":"100-0001"
                                        }
                                        """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.addressKanji").value("東京都千代田区"));
    }
}
