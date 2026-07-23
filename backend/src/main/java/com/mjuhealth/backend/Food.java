package com.mjuhealth.backend;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import lombok.Getter;
import lombok.Setter;

import java.time.LocalDateTime;

@Entity
@Getter
@Setter

public class Food {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    private String name;
    private  int calorie;
    private String digestTime;
    // 끼니 구분(아침/점심/저녁/간식) — 자동 판단 없이 사용자가 매번 직접 선택한 값을 그대로 저장
    private String meal;
    // 같은 날짜·같은 끼니에 동일 음식을 또 추가하면 새 행 대신 여기 누적 (FoodController.createFood 참고)
    private int quantity = 1;
    // Lombok이 boolean 필드 isTrigger에 대해 getter는 isTrigger(), setter는 setTrigger()로
    // 비대칭 생성하는 바람에 Jackson이 JSON 프로퍼티명을 "trigger"로 유도하는 문제가 있어
    // 프론트(app.js)와 맞추기 위해 JSON 프로퍼티명을 isTrigger로 고정함
    @JsonProperty("isTrigger")
    private boolean isTrigger;
    // 저장 시각: POST 때는 서버가 항상 자동으로 채우고, PUT 때만 값이 오면 갱신 (FoodController 참고)
    private LocalDateTime recordedAt;

    @ManyToOne(optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;
}
