package com.mjuhealth.backend;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class BackendApplication {

    public static void main(String[] args) {
        // Railway 서버(JVM)는 기본 시간대가 UTC라, LocalDateTime.now()를 쓰는 모든 곳
        // (FoodController/RunController의 recordedAt 기록 등)이 한국 시간 기준 자정~오전
        // 9시 사이엔 "어제" 날짜로 저장되는 문제가 있었음 — Spring이 뜨기 전에 가장 먼저
        // JVM 기본 시간대를 한국시간으로 고정해서 모든 now() 호출이 한국시간 기준이 되게 함
        java.util.TimeZone.setDefault(java.util.TimeZone.getTimeZone("Asia/Seoul"));
        SpringApplication.run(BackendApplication.class, args);
    }

}
