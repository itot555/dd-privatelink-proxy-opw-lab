package com.example.ddlab;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest(properties = "python.api.url=http://127.0.0.1:8000")
class DdLabApplicationTests {

    @Test
    void contextLoads() {
    }
}
